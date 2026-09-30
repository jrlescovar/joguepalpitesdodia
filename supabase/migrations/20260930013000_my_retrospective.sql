create or replace function public.get_my_retrospective()
returns jsonb language plpgsql stable security definer set search_path=public,auth,pg_temp as $$
declare target uuid := public.own_profile_id(); ending date := timezone('America/Sao_Paulo',now())::date; result jsonb;
begin
  if auth.uid() is null or target is null then raise exception 'Entre para ver sua retrospectiva.'; end if;

  select coalesce(jsonb_agg(jsonb_build_object('dayId',d.day_id::date,'greens',coalesce(s.greens,0),'points',coalesce(s.points,0)) order by d.day_id),'[]'::jsonb)
    into result
  from generate_series(ending-29,ending,interval '1 day') d(day_id)
  left join lateral (
    select count(*) filter(where p.status='green')::integer as greens,
      coalesce(sum(case when p.status='green' then
        coalesce((select (o->>'rankPoints')::integer from jsonb_array_elements(g.options) o where o->>'id'=p.option_id limit 1),0)
      else 0 end),0)::integer as points
    from public.picks p join public.predictions g on g.day_id=p.prediction_day and g.slot=p.slot
    where p.profile_id=target and p.prediction_day=d.day_id::date
  ) s on true;

  return result;
end;
$$;

revoke all on function public.get_my_retrospective() from public,anon,authenticated;
grant execute on function public.get_my_retrospective() to authenticated;
