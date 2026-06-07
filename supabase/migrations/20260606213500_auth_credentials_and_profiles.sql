-- Auth spine: user profiles + encrypted Spotify credentials.
--
-- profiles            : per-user public-ish profile, owner-readable via RLS.
-- spotify_credentials : per-user Spotify refresh token (encrypted) + collector state.
--                       SERVICE-ROLE ONLY. RLS is enabled with NO policies, so no client
--                       (anon/authenticated) can read or write it; only the service role
--                       (used by Edge Functions) can, because it bypasses RLS.

-- Keep updated_at fresh on any row update.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  spotify_user_id text,
  display_name    text,
  avatar_url      text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- spotify_credentials  (service-role only)
-- ---------------------------------------------------------------------------
create table public.spotify_credentials (
  user_id                  uuid primary key references auth.users (id) on delete cascade,
  spotify_user_id          text,
  -- AES-GCM encrypted Spotify refresh token. AAD binds it to user_id+key_version so a
  -- ciphertext copied to another row cannot be decrypted.
  refresh_token_ciphertext text not null,
  refresh_token_nonce      text not null,  -- unique IV per encryption; never reused with a key
  key_version              integer not null default 1,
  encrypted_at             timestamptz not null default now(),
  -- Collector state.
  last_collected_after_ms  bigint,         -- Spotify "after" cursor (ms since epoch)
  last_success_at          timestamptz,
  last_error               text,
  token_refresh_failed_at  timestamptz,
  reauth_required          boolean not null default false,
  enabled                  boolean not null default true,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

alter table public.spotify_credentials enable row level security;
-- Intentionally NO policies: clients get zero access; only the service role reaches this table.

create trigger spotify_credentials_set_updated_at
  before update on public.spotify_credentials
  for each row execute function public.set_updated_at();
