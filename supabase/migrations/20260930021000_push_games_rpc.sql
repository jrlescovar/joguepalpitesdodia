create function public.get_push_games_today() returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'day_id',day_id,'slot',slot,'title',title,'status',status,
    'closes_at',closes_at,'settled_at',settled_at) order by slot),'[]'::jsonb)
  from public.predictions
  where day_id=timezone('America/Sao_Paulo',now())::date;
$$;
revoke all on function public.get_push_games_today() from public,anon,authenticated;
grant execute on function public.get_push_games_today() to service_role;
