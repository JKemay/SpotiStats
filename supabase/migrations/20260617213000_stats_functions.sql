-- Phase 3: stats aggregation over play_events.
--
-- These are SECURITY INVOKER functions: they run as the calling user, so the `play_events`
-- owner-select RLS policy (auth.uid() = user_id) is enforced automatically. The explicit
-- `user_id = auth.uid()` filter is belt-and-suspenders and lets the planner use the
-- (user_id, played_at) index. `search_path = ''` + fully-qualified names keep them robust.
--
-- All "listening time" is an ESTIMATE: it sums each played track's full duration (the API proves
-- a track was played and when, not that it was heard in full). The UI labels it as such.
-- `p_days => null` means "all collected history" (which starts at connection time, not account
-- birth). Days are bucketed in UTC for v1 (the server doesn't know the user's timezone).

-- ---------------------------------------------------------------------------
-- Overview: headline counters for a window.
-- ---------------------------------------------------------------------------
create or replace function public.stats_overview(p_days integer default null)
-- Timestamps are returned as explicit UTC ISO-8601 strings (not timestamptz/date types) so
-- decoding doesn't depend on the client's date strategy; Swift parses them.
returns table (
  total_plays      bigint,
  est_listening_ms bigint,
  distinct_tracks  bigint,
  distinct_artists bigint,
  first_played_at  text,
  last_played_at   text
)
language sql
stable
security invoker
set search_path = ''
as $$
  with base as (
    select *
    from public.play_events
    where user_id = auth.uid()
      and (p_days is null or played_at >= now() - make_interval(days => p_days))
  )
  select
    (select count(*) from base)::bigint,
    (select coalesce(sum(duration_ms), 0) from base)::bigint,
    (select count(distinct coalesce(track_id, 'local:' || track_name)) from base)::bigint,
    (
      select count(distinct artist_name)
      from (select unnest(artist_names) as artist_name from base) u
      where artist_name <> ''
    )::bigint,
    (select to_char(min(played_at) at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') from base),
    (select to_char(max(played_at) at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') from base);
$$;

-- ---------------------------------------------------------------------------
-- Top tracks by play count (collected data — NOT Spotify's affinity windows).
-- Each track's display fields come from its most recent play's snapshot.
-- ---------------------------------------------------------------------------
create or replace function public.stats_top_tracks(p_limit integer default 20, p_days integer default null)
returns table (
  track_key     text,
  track_name    text,
  artist_names  text[],
  album_art_url text,
  play_count    bigint,
  est_ms        bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  with keyed as (
    select *, coalesce(track_id, 'local:' || track_name) as tkey
    from public.play_events
    where user_id = auth.uid()
      and (p_days is null or played_at >= now() - make_interval(days => p_days))
  ),
  agg as (
    select tkey, count(*)::bigint as play_count, coalesce(sum(duration_ms), 0)::bigint as est_ms
    from keyed
    group by tkey
  ),
  -- The display snapshot (name/artists/art) comes from each track's most recent play, since the
  -- catalog entry can change over time. DISTINCT ON avoids array_agg over the text[] column.
  latest as (
    select distinct on (tkey) tkey, track_name, artist_names, album_art_url
    from keyed
    order by tkey, played_at desc
  )
  select l.tkey, l.track_name, l.artist_names, l.album_art_url, a.play_count, a.est_ms
  from agg a
  join latest l using (tkey)
  order by a.play_count desc, a.est_ms desc
  limit greatest(p_limit, 0);
$$;

-- ---------------------------------------------------------------------------
-- Top artists by play count. A play credits every listed artist (so a feature
-- counts toward each), via unnest of the denormalized artist_names array.
-- ---------------------------------------------------------------------------
create or replace function public.stats_top_artists(p_limit integer default 20, p_days integer default null)
returns table (
  artist_name text,
  play_count  bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  select artist_name, count(*)::bigint as play_count
  from (
    select unnest(artist_names) as artist_name
    from public.play_events
    where user_id = auth.uid()
      and (p_days is null or played_at >= now() - make_interval(days => p_days))
  ) t
  where artist_name <> ''
  group by artist_name
  order by play_count desc
  limit greatest(p_limit, 0);
$$;

-- ---------------------------------------------------------------------------
-- Daily trend: per-day play count + estimated listening ms over a window.
-- ---------------------------------------------------------------------------
create or replace function public.stats_daily(p_days integer default 30)
returns table (
  day        text,
  play_count bigint,
  est_ms     bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    to_char((played_at at time zone 'UTC')::date, 'YYYY-MM-DD') as day,
    count(*)::bigint as play_count,
    coalesce(sum(duration_ms), 0)::bigint as est_ms
  from public.play_events
  where user_id = auth.uid()
    and played_at >= now() - make_interval(days => greatest(p_days, 1))
  group by (played_at at time zone 'UTC')::date
  order by (played_at at time zone 'UTC')::date;
$$;

-- Callable by signed-in users only; RLS still scopes every row to the caller.
grant execute on function public.stats_overview(integer) to authenticated;
grant execute on function public.stats_top_tracks(integer, integer) to authenticated;
grant execute on function public.stats_top_artists(integer, integer) to authenticated;
grant execute on function public.stats_daily(integer) to authenticated;
