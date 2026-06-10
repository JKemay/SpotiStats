-- Phase 2: the collector's data model + scheduling.
--
-- play_events    : one row per observed play, denormalized track snapshot. The Spotify catalog
--                  entry can change or vanish, so we snapshot what we saw at collection time.
--                  Owner-READABLE via RLS (Phase 3 stats read it); only the service role writes.
-- collector_runs : bookkeeping for each collector invocation (observability + debugging).
--                  SERVICE-ROLE ONLY, like spotify_credentials.
-- scheduling     : pg_cron invokes the collect-plays Edge Function every 10 minutes through
--                  pg_net, authenticated by a shared secret stored in Vault.

-- ---------------------------------------------------------------------------
-- play_events
-- ---------------------------------------------------------------------------
create table public.play_events (
  id              bigint generated always as identity primary key,
  user_id         uuid not null references auth.users (id) on delete cascade,
  played_at       timestamptz not null,
  -- Track snapshot. track_id is null for user-local tracks (no Spotify catalog id).
  track_id        text,
  track_name      text not null,
  artist_ids      text[] not null default '{}',
  artist_names    text[] not null default '{}',
  album_name      text,
  album_art_url   text,
  duration_ms     integer,
  explicit        boolean not null default false,
  is_local        boolean not null default false,
  context_uri     text,
  -- SHA-256 hex of a canonical JSON object identifying the play (see _shared/plays.ts).
  -- The unique constraint is what makes collection idempotent: overlapping fetches upsert
  -- with ON CONFLICT DO NOTHING instead of duplicating plays.
  idempotency_key text not null unique,
  created_at      timestamptz not null default now()
);

-- The two access patterns Phase 3 needs first: a user's history newest-first, and
-- per-track aggregation. GIN indexes on the arrays wait until a real query needs them.
create index play_events_user_played_at_idx on public.play_events (user_id, played_at desc);
create index play_events_user_track_idx on public.play_events (user_id, track_id);

alter table public.play_events enable row level security;

-- Owners can read their own plays; nobody but the service role can write
-- (no insert/update/delete policies on purpose).
create policy "play_events_select_own"
  on public.play_events for select
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- collector_runs  (service-role only)
-- ---------------------------------------------------------------------------
create table public.collector_runs (
  id              bigint generated always as identity primary key,
  started_at      timestamptz not null default now(),
  finished_at     timestamptz,
  status          text not null default 'running'
                  check (status in ('running', 'success', 'partial', 'failed')),
  trigger_source  text not null default 'cron',
  users_processed integer not null default 0,
  users_skipped   integer not null default 0,   -- e.g. rate-limited this run; retried next run
  users_failed    integer not null default 0,
  events_inserted integer not null default 0,
  error_summary   jsonb
);

alter table public.collector_runs enable row level security;
-- Intentionally NO policies: service role only (same advisor note as spotify_credentials).

-- ---------------------------------------------------------------------------
-- Scheduling: pg_cron -> pg_net -> collect-plays Edge Function
-- ---------------------------------------------------------------------------
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- The cron job calls this wrapper. It reads the function URL + invocation secret from Vault
-- AT EXECUTION TIME, so this migration applies cleanly even before the secrets exist —
-- the job just logs a warning until they're created (see deploy notes in docs/HANDOFF.md):
--   collect_plays_url    = https://<ref>.supabase.co/functions/v1/collect-plays
--   collect_plays_secret = the same value as the Edge Function secret COLLECT_PLAYS_SECRET
create or replace function public.invoke_collect_plays()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'collect_plays_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'collect_plays_secret';

  if v_url is null or v_secret is null then
    raise warning 'collect-plays: Vault secrets collect_plays_url / collect_plays_secret not set; skipping';
    return;
  end if;

  -- Async: pg_net queues the request and returns immediately; the Edge Function does the work.
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-collector-secret', v_secret
    ),
    body := jsonb_build_object('trigger', 'cron'),
    timeout_milliseconds := 15000
  );
end;
$$;

-- security definer + vault access means clients must NOT be able to call this.
revoke execute on function public.invoke_collect_plays() from public, anon, authenticated;

-- Every 10 minutes. Spotify keeps only the last 50 plays, so the ceiling between polls is
-- 50 tracks; at ~3 min/track even nonstop listening overflows only after ~2.5 hours.
-- 10 minutes is a comfortable margin with 144 runs/user/day, well within rate limits.
select cron.schedule(
  'collect-plays',
  '*/10 * * * *',
  $$select public.invoke_collect_plays()$$
);
