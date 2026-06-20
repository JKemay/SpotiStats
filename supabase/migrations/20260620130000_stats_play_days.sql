-- play_days: the DISTINCT UTC calendar dates on which the user has any play, newest first.
--
-- Each row is a "YYYY-MM-DD" string (UTC bucket) — the client uses these to compute listening
-- streaks without needing full timestamps. The `greatest(p_limit, 1)` guard ensures the LIMIT
-- clause is always positive even if a caller passes 0 or a negative.
--
-- `p_limit default 365` returns up to a rolling year of active days, which is more than enough
-- for streak calculations. Pass a larger value if a longer look-back is ever needed.

create or replace function public.stats_play_days(
    p_limit integer default 365
)
returns table (
    day text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    to_char((played_at at time zone 'UTC')::date, 'YYYY-MM-DD') as day
  from public.play_events
  where user_id = auth.uid()
  group by (played_at at time zone 'UTC')::date
  order by (played_at at time zone 'UTC')::date desc
  limit greatest(p_limit, 1);
$$;

-- Callable by signed-in users only; RLS still scopes every row to the caller.
grant execute on function public.stats_play_days(integer) to authenticated;
