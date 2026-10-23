begin;
set local statement_timeout='60s';
alter table public.public_profiles disable trigger user;
create temporary table master_checks(result text);
do $$
declare d date:=public.battle_today()+1;people uuid[];n integer;previous jsonb;original jsonb;
begin
 select jsonb_agg(to_jsonb(b) order by id) into original from public.daily_battles b where day_id=public.battle_today();
 delete from public.daily_battles where day_id=d;
 delete from public.daily_battle_reserved_pairings where day_id=d;
 insert into public.daily_battle_rounds(day_id) values(d) on conflict do nothing;
 update public.public_profiles set rank_points=0,created_at=(d+1)::timestamptz;
 select array_agg(gen_random_uuid()) into people from generate_series(1,12);
 for n in 1..12 loop
  insert into public.public_profiles(id,player_id,username,avatar_color,rank_points,battle_protected,created_at)
   values(people[n],99150000+n,'masterqa'||n,'#3b82f6',case when n<=10 then 10000-n when n=11 then 2119 else 2099 end,false,now()-interval '20 days');
 end loop;
 insert into public.daily_battles(day_id,player_left,result,settled_at) select d,id,'no_contest',now() from unnest(people[2:10]) t(id);
 insert into public.daily_battles(day_id,player_left) values(d,people[1]);
 perform public.pair_top10_daily_battles(d);
 if not exists(select 1 from public.daily_battles where day_id=d and player_left=people[1] and player_right=people[11]) then raise exception 'Master outside top ten not selected';end if;
 select jsonb_agg(to_jsonb(b) order by id) into previous from public.daily_battles b where day_id=d;
 perform public.pair_waiting_daily_battles(d);
 if previous is distinct from (select jsonb_agg(to_jsonb(b) order by id) from public.daily_battles b where day_id=d) then raise exception 'Assigned matchup redrawn';end if;
 insert into master_checks values('Top-ten Master pairs with 2119 outside top ten, unlimited difference; assigned match preserved');
 delete from public.daily_battles where day_id=d;
 update public.public_profiles set rank_points=2200 where id=people[1];
 insert into public.daily_battles(day_id,player_left,result,settled_at) select d,id,'no_contest',now() from unnest(people[2:11]) t(id);
 insert into public.daily_battles(day_id,player_left) values(d,people[1]),(d,people[12]);
 perform public.pair_waiting_daily_battles(d);
 if exists(select 1 from public.daily_battles where day_id=d and player_left=people[1] and player_right is not null) then raise exception 'Fallback used a non-Master';end if;
 delete from public.daily_battles where day_id=d and player_left=people[12];
 perform public.join_daily_battle_bye(people[12],d);
 if exists(select 1 from public.daily_battles where day_id=d and player_left=people[1] and player_right is not null) then raise exception 'Late entry bypassed Master minimum';end if;
 insert into master_checks values('No 2099 opponent in priority, ordinary fallback or late entry');
 delete from public.daily_battles where day_id=d;
 insert into public.daily_battles(day_id,player_left,player_right) values(d-1,people[1],people[11]);
 insert into public.daily_battles(day_id,player_left,result,settled_at) select d,id,'no_contest',now() from unnest(people[2:10]) t(id);
 insert into public.daily_battles(day_id,player_left) values(d,people[1]);
 perform public.pair_top10_daily_battles(d);
 if exists(select 1 from public.daily_battles where day_id=d and player_left=people[1] and player_right is not null) then raise exception 'Yesterday repeated';end if;
 if position('case when r.id=any(required)' in pg_get_functiondef('public.pair_top10_daily_battles(date)'::regprocedure))>0 then raise exception 'Still prefers a top-ten rival';end if;
 if has_function_privilege('authenticated','public.pair_top10_daily_battles(date)','execute') then raise exception 'Permission leak';end if;
 insert into master_checks values('No consecutive opponent; no top-ten rival preference; internal permissions preserved');
 -- The only change to today's matches in this test is our synthetic previous-day fixture.
 delete from public.daily_battles where day_id=d-1 and player_left=people[1];
 if original is distinct from (select jsonb_agg(to_jsonb(b) order by id) from public.daily_battles b where day_id=public.battle_today()) then raise exception 'Current matches changed';end if;
 insert into master_checks values('Real current matchups preserved');
end $$;
select jsonb_agg(result) passed from master_checks;
rollback;
