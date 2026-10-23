-- Synthetic players and dates; every mutation is rolled back.
begin;
set local statement_timeout='30s';
create temporary table weekly_real_profiles as select id,to_jsonb(p) data from public.public_profiles p;
create temporary table weekly_real_titles as select award_key,to_jsonb(t) data from public.arena_week_titles t;
alter table public.public_profiles disable trigger user;
alter table public.predictions disable trigger user;
alter table public.picks disable trigger user;
create or replace function public.battle_today() returns date language sql stable as $$select date '2072-01-10'$$;
create temporary table weekly_cases(result text);
do $$
declare w date:=date '2072-01-04';a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();payload jsonb; winner uuid; auth_id uuid;
begin
 select auth_user_id into auth_id from public.private_profiles where profile_id=(select id from public.public_profiles where player_id=1000001);
 perform set_config('request.jwt.claim.sub',auth_id::text,true);
 insert into public.public_profiles(id,player_id,username,avatar_color,rank_points,level) values
 (a,99132001,'weektie1','#3b82f6',5000,1),(b,99132002,'weektie2','#3b82f6',4000,50);
 insert into public.arena_weeks(week_start) values(w);
 insert into public.liga_week_participants(week_start,profile_id,seed) values(w,a,2),(w,b,1);
 insert into public.predictions(day_id,title,options,closes_at,status)
 select w+i,'Weekly tiebreak QA','[{"id":"100","label":"100","rankPoints":100},{"id":"50","label":"50","rankPoints":50},{"id":"150","label":"150","rankPoints":150}]'::jsonb,(w+i)::timestamptz,'settled' from generate_series(0,6)i;
 insert into public.picks(profile_id,prediction_day,option_id,status) values(a,w,'100','green'),(b,w,'50','green'),(b,w+1,'50','green');
 perform public.refresh_weekly_arena();
 select winner_id into winner from public.arena_weeks where week_start=w;
 payload:=public.get_arena();
 if winner is distinct from a or payload#>>'{week,standings,0,uid}'<>a::text then raise exception 'Global rank must precede greens, level and enrollment seed';end if;
 if (payload#>>'{week,standings,0,points}')::int<>100 or (payload#>>'{week,standings,1,greens}')::int<>2 then raise exception 'Scoring changed';end if;
 insert into weekly_cases values('Weekly standings and winner prefer global position over greens, level and seed');
 update public.picks set option_id='100' where profile_id=b and prediction_day=w;
 perform public.refresh_weekly_arena();payload:=public.get_arena();
 if (select winner_id from public.arena_weeks where week_start=w) is distinct from b or payload#>>'{week,standings,0,uid}'<>b::text then raise exception 'Weekly points must remain primary';end if;
 insert into weekly_cases values('Weekly points remain primary');
 update public.picks set option_id='50' where profile_id=b and prediction_day=w;
 update public.public_profiles set rank_points=6000 where id=b;
 perform public.refresh_weekly_arena();payload:=public.get_arena();
 if (select winner_id from public.arena_weeks where week_start=w) is distinct from b or payload#>>'{week,standings,0,uid}'<>b::text then raise exception 'Current global position not reflected';end if;
 insert into weekly_cases values('Current global rank changes are used consistently');
 update public.public_profiles set rank_points=5000 where id=b;
 perform public.refresh_weekly_arena();payload:=public.get_arena();
 if (select winner_id from public.arena_weeks where week_start=w) is distinct from a or payload#>>'{week,standings,0,uid}'<>a::text then raise exception 'Must use exact global position for equal PontosRank';end if;
 if payload#>>'{week,standings,0,globalPosition}' <> public.battle_rank_meta(a)->>'globalPosition' then raise exception 'Displayed global position differs';end if;
 insert into weekly_cases values('Exact global ranking position agrees with public profile, including equal PontosRank');
 update public.predictions set status='open' where day_id=w+6;
 perform public.refresh_weekly_arena();
 if exists(select 1 from public.arena_week_titles where week_start=w) then raise exception 'Awarded before all results';end if;
 update public.predictions set status='settled' where day_id=w+6;
 perform public.refresh_weekly_arena();perform public.refresh_weekly_arena();
 if (select count(*) from public.arena_week_titles where week_start=w)<>1 then raise exception 'Duplicate or missing title';end if;
 insert into weekly_cases values('Pending results gate settlement; repeat settlement is idempotent');
 if exists(select 1 from weekly_real_profiles old left join public.public_profiles p on p.id=old.id where to_jsonb(p) is distinct from old.data) then raise exception 'Real player data changed';end if;
 if exists(select 1 from weekly_real_titles old left join public.arena_week_titles t on t.award_key=old.award_key where to_jsonb(t) is distinct from old.data) then raise exception 'Historical titles changed';end if;
 if has_function_privilege('anon','public.get_arena()','execute') or has_function_privilege('authenticated','public.refresh_weekly_arena()','execute') then raise exception 'Permissions leaked';end if;
 insert into weekly_cases values('Real players, historical titles and function permissions preserved');
end $$;
select jsonb_agg(result) passed from weekly_cases;
rollback;
