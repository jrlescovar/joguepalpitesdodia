-- Run in the same transaction as the new Liga migration, then roll back.
create or replace function public.battle_today() returns date language sql stable as $$select coalesce(nullif(current_setting('liga.test_day',true),''),(timezone('America/Sao_Paulo',now())::date)::text)::date$$;
alter table public.predictions disable trigger user;
alter table public.picks disable trigger user;
alter table public.predictions drop constraint valid_prediction_options;
do $$
declare w date:=date '2072-01-04'; a uuid; b uuid; snapshot jsonb; before_daily bigint;
begin
 select jsonb_agg(to_jsonb(t) order by award_key) into snapshot from public.arena_week_titles t where week_start<date '2026-10-19';
 select sum(arena_wins) into before_daily from public.public_profiles;
 insert into public.public_profiles(id,player_id,username,avatar_color,rank_points) values(gen_random_uuid(),99131001,'ligatest1','#3b82f6',100) returning id into a;
 insert into public.public_profiles(id,player_id,username,avatar_color,rank_points) values(gen_random_uuid(),99131002,'ligatest2','#3b82f6',100) returning id into b;
 insert into public.arena_weeks(week_start) values(w);
 insert into public.liga_week_participants(week_start,profile_id,seed) values(w,a,1),(w,b,2);
 insert into public.predictions(day_id,title,options,closes_at,status)
 select w+i,'Liga QA','[{"id":"yes","label":"Yes","rankPoints":100}]'::jsonb,(w+i)::timestamptz,'settled' from generate_series(0,6)i;
 insert into public.arena_week_scores(week_start,day_id,profile_id,seed,level) select w,w+i,p.id,p.seed,1 from generate_series(0,6)i cross join (values(a,1),(b,2))p(id,seed);
 insert into public.picks(profile_id,prediction_day,option_id,status) select a,w+i,'yes','green' from generate_series(0,3)i;
 insert into public.picks(profile_id,prediction_day,option_id,status) select b,w+i,'yes','green' from generate_series(0,6)i;
 perform set_config('liga.test_day',(w+4)::text,true);perform public.refresh_weekly_arena();
 if exists(select 1 from public.arena_week_matches where week_start=w) then raise exception 'Created knockout';end if;
 if exists(select 1 from public.arena_week_titles where week_start=w) then raise exception 'Awarded before Sunday';end if;
 perform set_config('liga.test_day',(w+6)::text,true);
 update public.predictions set status='open' where day_id=w+6;
 perform public.refresh_weekly_arena();
 if exists(select 1 from public.arena_week_titles where week_start=w) then raise exception 'Awarded with pending Sunday';end if;
 update public.predictions set status='settled' where day_id=w+6;
 perform public.refresh_weekly_arena();perform public.refresh_weekly_arena();
 if (select winner_id from public.arena_weeks where week_start=w) is distinct from b then raise exception 'Weekend points not counted';end if;
 if (select sum(points) from public.arena_week_scores where week_start=w and profile_id=b)<>700 then raise exception 'Wrong seven day sum';end if;
 if (select count(*) from public.arena_week_titles where week_start=w and profile_id=b)<>1 then raise exception 'Missing or duplicate title';end if;
 if snapshot is distinct from (select jsonb_agg(to_jsonb(t) order by award_key) from public.arena_week_titles t where week_start<date '2026-10-19') then raise exception 'Historical titles changed';end if;
 if (select sum(arena_wins) from public.public_profiles)<>before_daily then raise exception 'Daily medals changed';end if;
 perform set_config('request.jwt.claims','{}',true);
 begin perform public.get_liga_week_history();raise exception 'Anonymous access allowed';exception when others then if sqlerrm='Anonymous access allowed' then raise;end if;end;
 if has_function_privilege('authenticated','public.refresh_weekly_arena()','execute') then raise exception 'Write permission leaked';end if;
end;$$;
select 'Seven day scoring, pending result, no knockout, single title, historical medals and authorization passed' as result;
