begin;
alter table public.arena_entries add column level integer not null default 1 check(level>=1);
update public.arena_entries e set level=p.level from public.public_profiles p where p.id=e.profile_id;
create function public.arena_winner(p_day date) returns uuid language sql stable security definer set search_path=public,pg_temp as $$
 select profile_id from public.arena_entries where day_id=p_day order by points desc,greens desc,level desc,seed limit 1;
$$;
revoke all on function public.arena_winner(date) from public,anon,authenticated;
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.refresh_arena_round(date)'::regprocedure);
 definition:=replace(definition,'set points=s.points,greens=s.greens from','set points=s.points,greens=s.greens,level=(select p.level from public.public_profiles p where p.id=e.profile_id) from');
 definition:=replace(definition,'select profile_id into champion from public.arena_entries where day_id=p_day order by points desc,greens desc,seed limit 1;','champion:=public.arena_winner(p_day);');
 if position('champion:=public.arena_winner(p_day)' in definition)=0 then raise exception 'Arena winner replacement failed'; end if;
 execute definition;
 definition:=pg_get_functiondef('public.get_arena()'::regprocedure);
 definition:=replace(definition,'order by e.points desc,e.greens desc,e.seed','order by e.points desc,e.greens desc,e.level desc,e.seed');
 if position('e.level desc' in definition)=0 then raise exception 'Arena ordering replacement failed'; end if;
 execute definition;
end;$$;
select public.refresh_arena_round(public.battle_today());
commit;
