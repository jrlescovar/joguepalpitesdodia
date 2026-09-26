-- Return the signed-in player's result alongside each settled game.
create or replace function public.get_recent_results()
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select coalesce(
    jsonb_agg(
      public.prediction_json(p) || jsonb_build_object('myPickStatus', k.status)
      order by p.day_id desc, p.slot asc
    ),
    '[]'::jsonb
  )
  from public.predictions p
  left join public.picks k
    on k.prediction_day = p.day_id
    and k.slot = p.slot
    and k.profile_id = public.own_profile_id()
  where p.day_id between timezone('America/Sao_Paulo', now())::date - 1
    and timezone('America/Sao_Paulo', now())::date
    and p.status = 'settled';
$$;
revoke all on function public.get_recent_results() from public, anon, authenticated;
grant execute on function public.get_recent_results() to authenticated;
notify pgrst, 'reload schema';
