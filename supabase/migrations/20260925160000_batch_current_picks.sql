create or replace function public.get_picks_for_day(p_day_id date)
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'dayId', prediction_day,
    'slot', slot,
    'optionId', option_id,
    'status', status
  ) order by slot), '[]'::jsonb)
  from public.picks
  where profile_id = public.own_profile_id() and prediction_day = p_day_id;
$$;

revoke execute on function public.get_picks_for_day(date) from public, anon, authenticated;
grant execute on function public.get_picks_for_day(date) to authenticated;

notify pgrst, 'reload schema';
