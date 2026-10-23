-- Run after the migration inside a transaction ending in ROLLBACK.
insert into public.public_profiles(id,player_id,username,avatar_color,daily_streak_current,last_played_prediction)
values('bbbbbb21-0000-4000-8000-000000000001',9902101,'streakqa1','#3b82f6',0,null),
 ('bbbbbb21-0000-4000-8000-000000000002',9902102,'streakqa2','#3b82f6',0,null),
 ('bbbbbb21-0000-4000-8000-000000000003',9902103,'streakhuman','#3b82f6',8,'2000-01-03');
insert into public.daily_bot_accounts(profile_id) values
 ('bbbbbb21-0000-4000-8000-000000000001'),('bbbbbb21-0000-4000-8000-000000000002');
insert into public.predictions(day_id,slot,title,options,closes_at,status)
select day::date,slot::smallint,'Calendar streak QA','[{"id":"home","label":"Casa","rankPoints":10},{"id":"away","label":"Fora","rankPoints":10}]'::jsonb,
 day::timestamptz+interval '18 hours','open'
from generate_series('2000-01-01'::timestamp,'2000-01-07','1 day') day cross join (values(0),(1)) s(slot)
on conflict(day_id,slot) do nothing;
insert into public.picks(profile_id,prediction_day,slot,option_id)
select 'bbbbbb21-0000-4000-8000-000000000001',day_id,0,'home' from public.predictions where slot=0
and day_id between '2000-01-01' and '2000-01-07' and day_id<>'2000-01-06';
insert into public.picks(profile_id,prediction_day,slot,option_id) values
 ('bbbbbb21-0000-4000-8000-000000000001','2000-01-06',1,'home'),
 ('bbbbbb21-0000-4000-8000-000000000002','2000-01-07',0,'home');
do $$ declare value jsonb;begin
 value:=public.bot_calendar_streak('bbbbbb21-0000-4000-8000-000000000001','2000-01-04');
 if value<>jsonb_build_object('current',4,'lastDay','2000-01-04') then raise exception 'Advance picks/current date: %',value;end if;
 value:=public.bot_calendar_streak('bbbbbb21-0000-4000-8000-000000000001','2000-01-05');
 if (value->>'current')::integer<>5 then raise exception 'Did not advance without new insertion';end if;
 value:=public.bot_calendar_streak('bbbbbb21-0000-4000-8000-000000000001','2000-01-06');
 if value<>jsonb_build_object('current',5,'lastDay','2000-01-05') then raise exception 'Extra counted as primary';end if;
 value:=public.bot_calendar_streak('bbbbbb21-0000-4000-8000-000000000001','2000-01-07');
 if value<>jsonb_build_object('current',1,'lastDay','2000-01-07') then raise exception 'Missing day did not reset';end if;
 value:=public.bot_calendar_streak('bbbbbb21-0000-4000-8000-000000000002','2000-01-04');
 if value<>jsonb_build_object('current',0,'lastDay',null) then raise exception 'Future-only picks counted';end if;
 if public.bot_calendar_streak('bbbbbb21-0000-4000-8000-000000000003','2000-01-04') is not null then raise exception 'Human rule modified';end if;
 if (public.get_public_profile('bbbbbb21-0000-4000-8000-000000000003')->>'dailyStreakCurrent')::integer<>8 then raise exception 'Human response modified';end if;
 if has_function_privilege('authenticated','public.bot_calendar_streak(uuid,date)','EXECUTE') or has_function_privilege('anon','public.bot_calendar_streak(uuid,date)','EXECUTE') then raise exception 'Internal helper exposed';end if;
end $$;
-- Move the server date to test serialization of already-existing future picks.
create or replace function public.battle_today() returns date language sql stable as $$select date '2000-01-04'$$;
do $$ declare value jsonb;begin
 value:=public.get_public_profile('bbbbbb21-0000-4000-8000-000000000001');
 if (value->>'dailyStreakCurrent')::integer<>4 or value->>'lastPlayedPrediction'<>'2000-01-04' then raise exception 'Public profile not derived from history';end if;
end $$;
create or replace function public.battle_today() returns date language sql stable as $$select date '2000-01-05'$$;
do $$begin
 if (public.get_public_profile('bbbbbb21-0000-4000-8000-000000000001')->>'dailyStreakCurrent')::integer<>5 then raise exception 'Profile froze next day without new pick';end if;
end $$;
