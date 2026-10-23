-- Run after migration inside BEGIN/ROLLBACK. Fixtures and deterministic RNG are rolled back.
-- Run after migration inside BEGIN/ROLLBACK. No test data is persisted.
-- Run after the migration inside a transaction ending in ROLLBACK.
select pg_advisory_xact_lock(hashtextextended('daily-bot-picks',0));
create temporary table real_bot_profiles_before as select id,to_jsonb(p) as data from public.public_profiles p;
delete from public.daily_bot_accounts;
update public.daily_bot_settings set enabled=false where singleton;
create or replace function public.battle_today() returns date language sql stable as $$select '2099-10-08'::date;$$;
insert into public.public_profiles(id,player_id,username,avatar_color,level,xp,daily_streak_current)
values ('aaaaaaaa-1111-4111-8111-111111111111',9900101,'tbotqa1','#3b82f6',2,10,3),
 ('bbbbbbbb-2222-4222-8222-222222222222',9900102,'tbotqa2','#22c55e',1,0,0),
 ('cccccccc-3333-4333-8333-333333333333',9900103,'thumanqa','#ec4899',1,0,0);
create temporary table tournament_bot_profile_snapshot as select id,to_jsonb(p) as data from public.public_profiles p where player_id between 9900101 and 9900103;
insert into public.daily_bot_accounts(profile_id) values('aaaaaaaa-1111-4111-8111-111111111111'),('bbbbbbbb-2222-4222-8222-222222222222');
insert into public.paid_tournaments(id,name,metric,starts_at,ends_at,entry_cents,prize_cents,prize_mode,enabled)
select id::uuid,'Torneio teste isolado','cards',public.battle_today_real_start,public.battle_today_real_start+interval '3 days',333,0,'entries',active
from (values('dddddddd-4444-4444-8444-444444444444',true),('eeeeeeee-5555-4555-8555-555555555555',false)) v(id,active)
cross join lateral(select ((clock_timestamp() at time zone 'America/Sao_Paulo')::date::text||'T00:00:00-03:00')::timestamptz as battle_today_real_start) public;
insert into public.paid_tournament_entries(tournament_id,profile_id,registration_source)
values('dddddddd-4444-4444-8444-444444444444','aaaaaaaa-1111-4111-8111-111111111111','admin'),
 ('dddddddd-4444-4444-8444-444444444444','cccccccc-3333-4333-8333-333333333333','admin'),
 ('eeeeeeee-5555-4555-8555-555555555555','aaaaaaaa-1111-4111-8111-111111111111','admin');
insert into public.paid_tournament_predictions(tournament_id,slot,match_day,home_team,away_team,title,closes_at,status,winning_option_id,settled_at,home_shots,away_shots)
select 'dddddddd-4444-4444-8444-444444444444',slot::smallint,(deadline at time zone 'America/Sao_Paulo')::date,'Casa QA','Fora QA','Quem terá mais cartões?',deadline,
 case when slot=5 then 'settled' else 'open' end,case when slot=5 then 'home' end,case when slot=5 then now() end,case when slot=5 then 1 end,case when slot=5 then 0 end
from (values(1,clock_timestamp()+interval '1 hour'),(2,clock_timestamp()+interval '2 hours'),(3,clock_timestamp()+interval '1 day'),(4,clock_timestamp()-interval '1 hour'),(5,clock_timestamp()+interval '2 hours')) v(slot,deadline);
insert into public.paid_tournament_predictions(tournament_id,slot,match_day,home_team,away_team,closes_at)
values('eeeeeeee-5555-4555-8555-555555555555',1,((clock_timestamp()+interval '1 hour') at time zone 'America/Sao_Paulo')::date,'Casa QA','Fora QA',clock_timestamp()+interval '1 hour');
insert into public.paid_tournament_picks(tournament_id,slot,profile_id,option_id)
values('dddddddd-4444-4444-8444-444444444444',1,'aaaaaaaa-1111-4111-8111-111111111111','away');


-- One event after its deadline, one from the prior date, one upcoming,
-- one in settlement, one already settled, and a confirmed pick to preserve.
insert into public.predictions(day_id,slot,title,options,closes_at,status)
select day_id::date,slot::smallint,'Unfinished bot QA',
 '[{"id":"a","label":"Casa","rankPoints":5},{"id":"b","label":"Fora","rankPoints":15}]'::jsonb,
 case when slot=2 then now()+interval '1 day' else now()-interval '1 day' end,status
from (values ('2099-10-08',0,'open'),('2099-10-07',0,'open'),('2099-10-09',2,'open'),
 ('2099-10-08',3,'settling'),('2099-10-08',4,'settled'),('2099-10-08',5,'open')) v(day_id,slot,status);
insert into public.picks(profile_id,prediction_day,slot,option_id)
values('aaaaaaaa-1111-4111-8111-111111111111','2099-10-08',5,'b');
select set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'email',
 (select owner_email from public.app_config where singleton))::text,true);


create or replace function public.wheel_random_index(p_count integer) returns integer language sql volatile as $$select 0;$$;
insert into public.predictions(day_id,slot,title,options,closes_at,status)
select '2099-10-10',slot::smallint,'Bot risk diversity QA',options::jsonb,now()+interval '1 day','open'
from (values
 (0,'[{"id":"safe","label":"Seguro","rankPoints":5},{"id":"risk","label":"Risco","rankPoints":50},{"id":"none","label":"Nenhum","rankPoints":360}]'),
 (1,'[{"id":"none","label":"Nenhum","rankPoints":360},{"id":"other","label":"Outro","rankPoints":120}]'),
 (2,'[{"id":"safe","label":"Seguro","rankPoints":5},{"id":"none","label":"Nenhum","rankPoints":360}]'),
 (3,'[{"id":"safe","label":"Seguro","rankPoints":5},{"id":"risk","label":"Risco","rankPoints":50}]'),
 (4,'[{"id":"safe","label":"Seguro","rankPoints":5},{"id":"risk","label":"Risco","rankPoints":50}]')) v(slot,options);
insert into public.picks(profile_id,prediction_day,slot,option_id) values
 ('aaaaaaaa-1111-4111-8111-111111111111','2099-10-10',3,'risk'),
 ('bbbbbbbb-2222-4222-8222-222222222222','2099-10-10',4,'safe');
create temporary table smart_confirmed_before as select to_jsonb(p) as data from public.picks p where profile_id in ('aaaaaaaa-1111-4111-8111-111111111111','bbbbbbbb-2222-4222-8222-222222222222') and prediction_day='2099-10-10';
select public.admin_run_daily_bots_now();
do $$
begin
 if (select count(distinct option_id) from public.picks where prediction_day='2099-10-10' and slot=0)<>2 then raise exception 'All bots selected same option'; end if;
 if exists(select 1 from public.picks where prediction_day='2099-10-10' and (slot=1 or option_id='none')) then raise exception 'Above-100 option selected'; end if;
 if (select count(*) from public.picks where prediction_day='2099-10-10' and slot=2 and option_id='safe')<>2 then raise exception 'Single eligible choice was skipped'; end if;
 if (select count(distinct option_id) from public.picks where prediction_day='2099-10-10' and slot=3)<>2 or (select count(distinct option_id) from public.picks where prediction_day='2099-10-10' and slot=4)<>2 then raise exception 'Diversity with existing pick failed'; end if;
 if exists(select 1 from smart_confirmed_before s where not exists(select 1 from public.picks p where to_jsonb(p)=s.data)) then raise exception 'Confirmed pick modified'; end if;
 if exists(select 1 from public.daily_bot_pick_log where prediction_day='2099-10-10' and slot=1) then raise exception 'Excluded event logged a pick'; end if;
end;
$$;
create temporary table smart_profiles_after as select id,to_jsonb(p) as data from public.public_profiles p;
select public.admin_run_daily_bots_now();
do $$
begin
 if exists(select 1 from smart_profiles_after s join public.public_profiles p using(id) where s.data<>to_jsonb(p)) then raise exception 'Replay duplicated XP'; end if;
end;
$$;
select 'PASS: independently weighted bots, never unanimous with 2 choices, preserved confirmed picks, all-above-100 skip, single-choice exception, replay XP unchanged' as result;
