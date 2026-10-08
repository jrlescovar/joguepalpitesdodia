-- Execute after the migration inside a transaction, then roll back.
create or replace function public.battle_today() returns date language sql stable as $$select coalesce(nullif(current_setting('arena.test_day',true),''),(timezone('America/Sao_Paulo',now())::date)::text)::date$$;
alter table public.predictions disable trigger user;
alter table public.picks disable trigger user;
-- Synthetic weighted options isolate bracket scoring; this constraint change is rolled back.
alter table public.predictions drop constraint valid_prediction_options;
do $$
 declare w date:=date_trunc('week',date '2072-01-10')::date; ids uuid[]; options jsonb; i int; j int; payload jsonb; snapshot jsonb; expected uuid;
begin
 for i in 1..8 loop
  insert into public.public_profiles(id,player_id,username,avatar_color,rank_points) values(gen_random_uuid(),99110000+i,'weekqa'||i,'#3b82f6',100) returning id into expected;
  ids:=array_append(ids,expected);
 end loop;
 select jsonb_agg(jsonb_build_object('id','p'||n,'label','P'||n,'rankPoints',100-n*10)) into options from generate_series(1,8)n;
 insert into public.arena_weeks(week_start) values(w);
 insert into public.predictions(day_id,slot,title,options,closes_at,status)
 select w+day_offset,slot::smallint,'Weekly Arena QA extras','[{"id":"yes","label":"Yes","rankPoints":10},{"id":"no","label":"No","rankPoints":10}]'::jsonb,(w+day_offset)::timestamptz,'settled'
 from generate_series(0,6)day_offset cross join generate_series(1,9)slot;
 for j in 0..3 loop
  insert into public.predictions(day_id,title,options,closes_at,status)values(w+j,'Weekly Arena QA',options,(w+j)::timestamptz,'settled');
  for i in 1..8 loop
   insert into public.arena_week_scores(week_start,day_id,profile_id,seed,level)values(w,w+j,ids[i],i,1);
   insert into public.picks(profile_id,prediction_day,option_id,status)values(ids[i],w+j,'p'||i,'green');
  end loop;
 end loop;
 perform set_config('arena.test_day',(w+3)::text,true);perform public.refresh_weekly_arena();
 if exists(select 1 from public.arena_week_seeds where week_start=w) then raise exception 'Frozen before Friday'; end if;
 perform set_config('arena.test_day',(w+4)::text,true);
 update public.predictions set status='open' where day_id=w+3;
 perform public.refresh_weekly_arena();
 if exists(select 1 from public.arena_week_seeds where week_start=w) then raise exception 'Frozen with pending Thursday'; end if;
 update public.predictions set status='settled' where day_id=w+3;
 perform public.refresh_weekly_arena();
 if (select count(*) from public.arena_week_seeds where week_start=w)<>8 then raise exception 'Eight seeds missing'; end if;
 if not exists(select 1 from public.arena_week_matches where week_start=w and match_key='Q1' and home_seed=1 and away_seed=8)
 or not exists(select 1 from public.arena_week_matches where week_start=w and match_key='Q2' and home_seed=4 and away_seed=5)
 or not exists(select 1 from public.arena_week_matches where week_start=w and match_key='Q3' and home_seed=2 and away_seed=7)
 or not exists(select 1 from public.arena_week_matches where week_start=w and match_key='Q4' and home_seed=3 and away_seed=6) then raise exception 'Incorrect quarters'; end if;
 -- An upset on Friday must advance the winner, rather than the original seed.
 select jsonb_agg(jsonb_build_object('id','p'||n,'label','P'||n,'rankPoints',n*10)) into options from generate_series(1,8)n;
 insert into public.predictions(day_id,title,options,closes_at,status)values(w+4,'Weekly Arena QA',options,(w+4)::timestamptz,'open');
 for i in 1..8 loop insert into public.picks(profile_id,prediction_day,option_id,status)values(ids[i],w+4,'p'||i,'green');end loop;
 perform public.refresh_weekly_arena();
 if exists(select 1 from public.arena_week_matches where week_start=w and day_id=w+4 and status='finished') then raise exception 'Advanced on open result'; end if;
 update public.predictions set status='settled' where day_id=w+4;perform public.refresh_weekly_arena();
 if not exists(select 1 from public.arena_week_matches where week_start=w and match_key='S1' and home_id=ids[8] and away_id=ids[5])
 or not exists(select 1 from public.arena_week_matches where week_start=w and match_key='S2' and home_id=ids[7] and away_id=ids[6]) then raise exception 'Semifinal routing failed'; end if;
 if exists(select 1 from public.arena_week_matches where week_start=w and day_id=w+5 and status='finished') then raise exception 'Advanced without Saturday games'; end if;
 perform set_config('arena.test_day',(w+5)::text,true);
 insert into public.predictions(day_id,title,options,closes_at,status)values(w+5,'Weekly Arena QA','[{"id":"yes","label":"Yes","rankPoints":20}]',(w+5)::timestamptz,'settled');
 insert into public.picks(profile_id,prediction_day,option_id,status)values(ids[8],w+5,'yes','green'),(ids[7],w+5,'yes','green');
 perform public.refresh_weekly_arena();
 if not exists(select 1 from public.arena_week_matches where week_start=w and match_key='F' and home_id=ids[8] and away_id=ids[7] and home_points=0 and away_points=0) then raise exception 'Final routing / fresh score failed'; end if;
 perform set_config('arena.test_day',(w+6)::text,true);
 insert into public.predictions(day_id,title,options,closes_at,status)values(w+6,'Weekly Arena QA','[{"id":"yes","label":"Yes","rankPoints":20}]',(w+6)::timestamptz,'settled');
 insert into public.picks(profile_id,prediction_day,option_id,status)values(ids[8],w+6,'yes','green'),(ids[7],w+6,'yes','green');
 perform public.refresh_weekly_arena();perform public.refresh_weekly_arena();
 if (select winner_id from public.arena_weeks where week_start=w)<>ids[7] then raise exception 'Final tiebreak by qualifying seed failed'; end if;
 if (select count(*) from public.arena_week_titles where week_start=w and profile_id=ids[7])<>1 then raise exception 'Title duplicated or missing'; end if;
 if exists(select 1 from public.public_profiles where id=any(ids) and (rank_points<>100 or arena_wins<>0)) then raise exception 'Weekly title changed daily/global rewards'; end if;
 select jsonb_agg(to_jsonb(m) order by match_key) into snapshot from public.arena_week_matches m where week_start=w;
 update public.picks set status='red' where prediction_day=w+6;
 perform public.refresh_weekly_arena();
 if snapshot is distinct from (select jsonb_agg(to_jsonb(m) order by match_key) from public.arena_week_matches m where week_start=w) then raise exception 'Finished bracket changed'; end if;
 perform set_config('request.jwt.claims','{}',true);
 begin perform public.get_arena();raise exception 'Anonymous access allowed';exception when others then if sqlerrm='Anonymous access allowed' then raise;end if;end;
 if has_function_privilege('authenticated','public.refresh_weekly_arena()','execute') or has_table_privilege('authenticated','public.arena_week_titles','insert') then raise exception 'Private write access leaked';end if;
 -- Eligibility is capped at 100 and remains fixed when global rank changes.
 for i in 1..110 loop
  insert into public.public_profiles(id,player_id,username,avatar_color,rank_points)values(gen_random_uuid(),99120000+i,'topqa'||i,'#3b82f6',i);
 end loop;
 perform set_config('arena.test_day',(w+7)::text,true);perform public.ensure_arena_round(w+7);
 if (select count(*) from public.arena_entries where day_id=w+7)<>100 then raise exception 'Top 100 cap failed';end if;
 select jsonb_agg(to_jsonb(e) order by seed) into snapshot from public.arena_entries e where day_id=w+7;
 update public.public_profiles set rank_points=99999 where player_id=99120110;
 perform public.ensure_arena_round(w+7);
 if snapshot is distinct from (select jsonb_agg(to_jsonb(e) order by seed) from public.arena_entries e where day_id=w+7) then raise exception 'Eligibility changed mid-day';end if;
 perform set_config('arena.test_day',(w+11)::text,true);perform public.ensure_arena_round(w+11);
 if exists(select 1 from public.arena_rounds where day_id=w+11) then raise exception 'Traditional Friday round created';end if;
end;$$;
