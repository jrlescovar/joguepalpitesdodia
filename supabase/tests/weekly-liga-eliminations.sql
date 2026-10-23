begin;
-- Run with the candidate migration in the same transaction; roll back all fixtures.
set local statement_timeout='60s';
alter table public.public_profiles disable trigger user;
alter table public.predictions disable trigger user;
create temporary table elimination_checks(result text);
do $$
declare w date:=date '2072-01-04'; ids uuid[];i integer;payload jsonb;auth_id uuid;
begin
 if public.liga_week_daily_cut(50)<>6 or public.liga_week_daily_cut(27)<>2 or public.liga_week_daily_cut(10)<>0 or public.liga_week_daily_cut(9)<>0 or public.liga_week_daily_cut(16)<>1 then raise exception 'Incorrect daily quotas';end if;
 insert into elimination_checks values('Quotas: 50->6, 27->2, 16->1, <=10->0');
 insert into public.public_profiles(id,player_id,username,avatar_color,rank_points,level)
 select gen_random_uuid(),99140000+n,'cutqa'||n,'#3b82f6',10000-n,1 from generate_series(1,50)n;
 select array_agg(id order by player_id) into ids from public.public_profiles where player_id between 99140001 and 99140050;
 insert into public.arena_weeks(week_start) values(w),(w+7),(w+14);
 insert into public.liga_week_participants(week_start,profile_id,seed) select w,ids[n],n from generate_series(1,50)n;
 insert into public.arena_week_scores(week_start,day_id,profile_id,seed,points,greens,level)
 select w,w+d,ids[n],n,case when d=0 then n*10 when n<=6 then 10000 else 0 end,case when d=0 then 1 else 0 end,1 from generate_series(0,6)d cross join generate_series(1,50)n;
 insert into public.predictions(day_id,slot,title,options,closes_at,status)
 select w+d,n,'Elimination QA','[{"id":"home","label":"Casa","rankPoints":10},{"id":"draw","label":"X","rankPoints":20},{"id":"away","label":"Fora","rankPoints":30}]'::jsonb,(w+d)::timestamptz,'settled' from generate_series(0,6)d cross join generate_series(0,9)n;
 perform public.apply_liga_week_eliminations(w,w);
 if exists(select 1 from public.liga_week_eliminations where week_start=w) then raise exception 'Cut before day end';end if;
 perform public.apply_liga_week_eliminations(w,w+1);
 if (select count(*) from public.liga_week_eliminations where week_start=w)<>6 or exists(select 1 from public.liga_week_eliminations e where e.week_start=w and not(e.profile_id=any(ids[1:6]))) then raise exception 'Wrong Monday cut';end if;
 if exists(select 1 from public.arena_week_scores where week_start=w and profile_id=any(ids[1:6]) and day_id>w and (points<>0 or greens<>0)) then raise exception 'Eliminated player kept scoring';end if;
 if (select sum(points) from public.arena_week_scores where week_start=w and profile_id=ids[6])<>60 then raise exception 'Earned points removed';end if;
 insert into elimination_checks values('Monday cut uses cumulative weekly performance; preserves earned points and freezes later scoring');
 perform public.apply_liga_week_eliminations(w,w+1);
 if (select count(*) from public.liga_week_eliminations where week_start=w)<>6 then raise exception 'Repeated cut';end if;
 update public.predictions set status='open' where day_id=w+1 and slot=1;
 perform public.apply_liga_week_eliminations(w,w+6);
 if (select count(*) from public.liga_week_eliminations where week_start=w)<>6 then raise exception 'Skipped pending day';end if;
 update public.predictions set status='settled' where day_id=w+1;
 perform public.apply_liga_week_eliminations(w,w+6);
 if (select count(*) from public.liga_week_eliminations where week_start=w)<>36 or (select count(*) from public.liga_week_elimination_rounds where week_start=w)<>6 then raise exception 'Expected 14 Sunday survivors';end if;
 if (select count(*) from public.liga_week_eliminations where week_start=w and eliminated_on=w+1)<>6 then raise exception 'Tuesday did not skip previously eliminated players';end if;
 perform public.apply_liga_week_eliminations(w,w+7);
 if (select count(*) from public.liga_week_eliminations where week_start=w)<>36 then raise exception 'Sunday cut or duplicate';end if;
 insert into elimination_checks values('Pending results block subsequent cuts; six idempotent cuts leave 14/50; no Sunday elimination');
 -- A second week with equal weekly scores must cut the worst global positions.
 insert into public.liga_week_participants(week_start,profile_id,seed) select w+7,ids[n],n from generate_series(1,50)n;
 insert into public.arena_week_scores(week_start,day_id,profile_id,seed,points,greens,level) select w+7,w+7,ids[n],n,100,1,1 from generate_series(1,50)n;
 insert into public.predictions(day_id,slot,title,options,closes_at,status) select w+7,n,'Tie QA','[{"id":"home","label":"Casa","rankPoints":10},{"id":"draw","label":"X","rankPoints":20},{"id":"away","label":"Fora","rankPoints":30}]'::jsonb,(w+7)::timestamptz,'settled' from generate_series(0,9)n;
 perform public.apply_liga_week_eliminations(w+7,w+8);
 if exists(select 1 from public.liga_week_eliminations e where e.week_start=w+7 and not(e.profile_id=any(ids[45:50]))) or (select count(*) from public.liga_week_eliminations where week_start=w+7)<>6 then raise exception 'Global tiebreak reversed incorrectly';end if;
 insert into elimination_checks values('Weekly ties retain the better current global rank');
 insert into public.liga_week_participants(week_start,profile_id,seed) select w+14,ids[n],n from generate_series(1,10)n;
 insert into public.predictions(day_id,slot,title,options,closes_at,status) select w+14,n,'Small roster QA','[{"id":"home","label":"Casa","rankPoints":10},{"id":"draw","label":"X","rankPoints":20},{"id":"away","label":"Fora","rankPoints":30}]'::jsonb,(w+14)::timestamptz,'settled' from generate_series(0,9)n;
 perform public.apply_liga_week_eliminations(w+14,w+15);
 perform public.apply_liga_week_eliminations(date '2026-10-19',date '2026-10-25');
 if exists(select 1 from public.liga_week_eliminations where week_start in (w+14,date '2026-10-19')) or exists(select 1 from public.liga_week_elimination_rounds where week_start=date '2026-10-19') then raise exception 'Small roster or current week changed';end if;
 insert into elimination_checks values('Ten-player rosters and the current week remain untouched');
 if has_function_privilege('authenticated','public.apply_liga_week_eliminations(date,date)','execute') or has_table_privilege('authenticated','public.liga_week_eliminations','select') then raise exception 'Internal permission leak';end if;
 insert into elimination_checks values('Internal tables and cut function are private');
end $$;
do $$
declare definition text;payload jsonb;auth_id uuid;eliminated_id uuid;
begin
 select auth_user_id into auth_id from public.private_profiles where profile_id=(select id from public.public_profiles where player_id=1000001);
 perform set_config('request.jwt.claim.sub',auth_id::text,true);
 definition:=pg_get_functiondef('public.get_arena()'::regprocedure);
 definition:=replace(definition,'public.get_arena()','pg_temp.test_elimination_payload()');
 definition:=replace(definition,'d date:=public.battle_today()','d date:=date ''2072-01-10''');
 definition:=replace(definition,'perform public.ensure_arena_round(d); perform public.refresh_arena_round(d);','');
 execute definition;
 select id into eliminated_id from public.public_profiles where player_id=99140001;
 update public.arena_week_scores set points=99999 where week_start=date '2072-01-04' and day_id=date '2072-01-04' and profile_id=eliminated_id;
 payload:=pg_temp.test_elimination_payload();
 if jsonb_array_length(payload#>'{week,standings}')<>50 then raise exception 'Eliminated players disappeared from the table';end if;
 if payload#>>'{week,standings,0,uid}'<>eliminated_id::text or payload#>>'{week,standings,0,eliminatedOn}'<>'2072-01-04' then raise exception 'Eliminated leader lost position or elimination date';end if;
 insert into elimination_checks values('API keeps eliminated players and dates, including an eliminated leader');
end $$;
select jsonb_agg(result) passed from elimination_checks;

rollback;
