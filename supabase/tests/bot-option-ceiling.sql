-- Execute with the migration inside BEGIN/ROLLBACK; no fixtures persist.
select pg_advisory_xact_lock(hashtextextended('daily-bot-picks',0));
create temporary table ceiling_real_profiles as select id,to_jsonb(p) as data from public.public_profiles p;
create temporary table ceiling_real_picks as select profile_id,prediction_day,slot,to_jsonb(p) as data from public.picks p;
delete from public.daily_bot_accounts;
update public.daily_bot_settings set enabled=false where singleton;
insert into public.public_profiles(id,player_id,username,avatar_color)
values('aaaaaa15-0000-4000-8000-000000000001',9901501,'ceilingqa1','#22c55e'),
 ('aaaaaa15-0000-4000-8000-000000000002',9901502,'ceilingqa2','#22c55e');
insert into public.daily_bot_accounts(profile_id) values('aaaaaa15-0000-4000-8000-000000000001'),('aaaaaa15-0000-4000-8000-000000000002');
-- Deterministic roll picks the first candidate. Put the forbidden one first
-- and test BEFORE the old rollout date as well as after it.
create or replace function public.wheel_random_index(p_count integer) returns integer language sql volatile as $$select 0;$$;
insert into public.predictions(day_id,slot,title,options,closes_at,status)
select d::date,s::smallint,'Bot ceiling QA',opts::jsonb,now()-interval '1 day','open'
from (values
 ('2000-01-01',0,'[{"id":"none","label":"Nenhum","rankPoints":360},{"id":"home","label":"Casa","rankPoints":30},{"id":"away","label":"Fora","rankPoints":30}]'),
 ('2099-01-01',0,'[{"id":"none","label":"Nenhum","rankPoints":360},{"id":"home","label":"Casa","rankPoints":30},{"id":"away","label":"Fora","rankPoints":30}]'),
 ('2099-01-01',1,'[{"id":"over","label":"Acima","rankPoints":151},{"id":"limit","label":"Limite","rankPoints":150}]'),
 ('2099-01-01',2,'[{"id":"over","label":"Acima","rankPoints":151},{"id":"none","label":"Nenhum","rankPoints":360}]')) v(d,s,opts);
do $$
declare draws jsonb;
begin
 if public.run_daily_bot_picks()<>0 then raise exception 'Paused bots ran'; end if;
 update public.daily_bot_settings set enabled=true where singleton;
 perform public.run_daily_bot_picks();
 if exists(select 1 from public.picks where profile_id in ('aaaaaa15-0000-4000-8000-000000000001','aaaaaa15-0000-4000-8000-000000000002') and prediction_day in ('2000-01-01','2099-01-01') and option_id in ('none','over')) then raise exception 'Above 150 selected'; end if;
 if (select count(*) from public.picks where prediction_day in ('2000-01-01','2099-01-01') and profile_id in ('aaaaaa15-0000-4000-8000-000000000001','aaaaaa15-0000-4000-8000-000000000002'))<>6 then raise exception 'Allowed picks missing or all-excluded event played'; end if;
 if (select count(distinct option_id) from public.picks where prediction_day='2000-01-01' and slot=0)<>2 or (select count(distinct option_id) from public.picks where prediction_day='2099-01-01' and slot=0)<>2 then raise exception 'Safe alternatives/diversity failed'; end if;
 if public.bot_ranked_option('[{"id":"limit","rankPoints":150},{"id":"above","rankPoints":151}]',0.999999)<>'limit' then raise exception '150 boundary failed'; end if;
 if public.bot_ranked_option('[{"id":"above","rankPoints":151},{"id":"none","rankPoints":360}]',0.5) is not null then raise exception 'All-excluded helper failed'; end if;
 select jsonb_object_agg(chosen,n) into draws from (
  select public.bot_ranked_option('[{"id":"home","rankPoints":30},{"id":"none","rankPoints":360},{"id":"away","rankPoints":30}]',i/10000.0) chosen,count(*) n from generate_series(0,9999) i group by chosen
 ) t;
 if draws ? 'none' or draws->>'home'<>'5000' or draws->>'away'<>'5000' then raise exception 'Equal safe weights failed: %',draws; end if;
 select jsonb_object_agg(chosen,n) into draws from (
  select public.bot_ranked_option('[{"id":"safe","rankPoints":30},{"id":"risk","rankPoints":150}]',i/10000.0) chosen,count(*) n from generate_series(0,9999) i group by chosen
 ) t;
 if (draws->>'safe')::int<=(draws->>'risk')::int or (draws->>'risk')::int<=0 then raise exception 'Lower-point preference failed'; end if;
 if has_function_privilege('authenticated','public.bot_ranked_option(jsonb,double precision,text)','EXECUTE') or has_function_privilege('anon','public.run_daily_bot_picks()','EXECUTE') then raise exception 'Private worker exposed'; end if;
end;
$$;
create temporary table ceiling_profiles_after as select id,to_jsonb(p) as data from public.public_profiles p;
select public.run_daily_bot_picks();
do $$
begin
 if exists(select 1 from ceiling_profiles_after s join public.public_profiles p using(id) where s.data<>to_jsonb(p)) then raise exception 'Replay changed XP'; end if;
 if exists(select 1 from ceiling_real_profiles s join public.public_profiles p using(id) where s.data<>to_jsonb(p)) or exists(select 1 from ceiling_real_picks s join public.picks p using(profile_id,prediction_day,slot) where s.data<>to_jsonb(p)) then raise exception 'Real player data changed'; end if;
end;
$$;
select 'PASS: 150 boundary; 20000 safe draws; old/new dates; diversity; skipped all-excluded; pause; replay; real players unchanged' as result;
