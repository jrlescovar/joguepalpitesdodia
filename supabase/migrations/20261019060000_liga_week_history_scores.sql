begin;
create or replace function public.get_liga_week_history() returns jsonb
language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Entre para visualizar a Liga.'; end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('startsOn',t.week_start,'endsOn',t.week_start+6,'winner',public.get_public_profile(t.profile_id),'points',s.points,'greens',s.greens) order by t.week_start desc),'[]'::jsonb)
 from public.arena_week_titles t
 cross join lateral (
  select coalesce(sum((o.value->>'rankPoints')::int) filter(where k.status='green'),0) points,count(*) filter(where k.status='green') greens
  from public.picks k join public.predictions g on g.day_id=k.prediction_day and g.slot=k.slot
  left join lateral jsonb_array_elements(g.options)o(value) on o.value->>'id'=k.option_id
  where k.profile_id=t.profile_id and k.prediction_day between t.week_start and t.week_start+6
 )s where t.source='weekly' and t.week_start is not null);
end;$$;
notify pgrst,'reload schema';
commit;
