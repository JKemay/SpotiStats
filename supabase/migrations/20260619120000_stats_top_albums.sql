-- Top albums by play count, derived from collected play_events.
--
-- NOTE: play_events has no album_id — only album_name + album_art_url. We group by album_name,
-- so same-named albums by different artists (e.g. a self-titled) will merge into one row. This is
-- an acceptable v1 trade-off; fixing it would require a stable album_id column in play_events.
--
-- The display snapshot (art URL + artist list) comes from the most recent play per album_name via
-- DISTINCT ON, mirroring the stats_top_tracks approach.
--
-- `p_days => null` means all collected history (starts at connection time, bucketed in UTC).

create or replace function public.stats_top_albums(
    p_limit integer default 20,
    p_days  integer default null
)
returns table (
    album_key    text,
    album_name   text,
    album_art_url text,
    artist_names text[],
    play_count   bigint,
    est_ms       bigint
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
      and album_name is not null
      and album_name <> ''
      and (p_days is null or played_at >= now() - make_interval(days => p_days))
  ),
  agg as (
    select
      album_name,
      count(*)::bigint         as play_count,
      coalesce(sum(duration_ms), 0)::bigint as est_ms
    from base
    group by album_name
  ),
  -- Display snapshot: most-recent play's art URL and artist list, per album.
  latest as (
    select distinct on (album_name)
      album_name,
      album_art_url,
      artist_names
    from base
    order by album_name, played_at desc
  )
  select
    l.album_name           as album_key,
    l.album_name,
    l.album_art_url,
    l.artist_names,
    a.play_count,
    a.est_ms
  from agg a
  join latest l using (album_name)
  order by a.play_count desc, a.est_ms desc
  limit greatest(p_limit, 0);
$$;

-- Callable by signed-in users only; RLS still scopes every row to the caller.
grant execute on function public.stats_top_albums(integer, integer) to authenticated;
