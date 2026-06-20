-- Listening Clock: play counts grouped by weekday × hour-of-day so the client can render a
-- 7 × 24 heatmap.
--
-- NOTE: All bucketing is done in UTC (extract(dow/hour from … at time zone 'UTC')). The server
-- doesn't know the user's local timezone — adjusting to local time is a v1 limitation noted in
-- the UI with a "Times shown in UTC" caption.
--
-- weekday: 0 = Sunday … 6 = Saturday  (PostgreSQL DOW convention).
-- hour:    0 … 23 (UTC hour).
-- `p_days => null` means all collected history.

create or replace function public.stats_listening_clock(
    p_days integer default null
)
returns table (
    weekday    integer,
    hour       integer,
    play_count bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    extract(dow  from (played_at at time zone 'UTC'))::int as weekday,
    extract(hour from (played_at at time zone 'UTC'))::int as hour,
    count(*)::bigint                                        as play_count
  from public.play_events
  where user_id = auth.uid()
    and (p_days is null or played_at >= now() - make_interval(days => p_days))
  group by 1, 2
  order by 1, 2;
$$;

-- Callable by signed-in users only; RLS still scopes every row to the caller.
grant execute on function public.stats_listening_clock(integer) to authenticated;
