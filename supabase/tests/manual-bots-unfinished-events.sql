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

do $$
declare before_profile jsonb; expected_count integer; expected_xp integer[]; after_profile jsonb; state jsonb;
begin
 if public.run_daily_bot_picks()<>0 then raise exception 'Disabled bots ran'; end if;
 -- Tournament-only run also covers expired events; ordinary XP must not change.
 update public.daily_bot_settings set enabled=true where singleton;
 if public.run_tournament_bot_picks()<>3 then raise exception 'Expired tournament event missing'; end if;
 if public.run_tournament_bot_picks()<>0 then raise exception 'Tournament replay duplicated'; end if;
 if exists(select 1 from tournament_bot_profile_snapshot s join public.public_profiles p using(id) where s.data<>to_jsonb(p)) then raise exception 'Tournament changed global XP'; end if;
 -- Past tournament end must not exclude an event still awaiting its result.
 update public.paid_tournaments set starts_at=date_trunc('day',now() at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo'-interval '3 days',ends_at=(date_trunc('day',now() at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo')-interval '1 day'+interval '10 hours' where id='dddddddd-4444-4444-8444-444444444444';
 insert into public.paid_tournament_predictions(tournament_id,slot,match_day,home_team,away_team,closes_at)
 values('dddddddd-4444-4444-8444-444444444444',6,((now()-interval '2 days') at time zone 'America/Sao_Paulo')::date,'Casa QA','Fora QA',now()-interval '2 days');
 if public.run_tournament_bot_picks()<>1 then raise exception 'Past tournament end suppressed unfinished event'; end if;
 if exists(select 1 from public.paid_tournament_picks where tournament_id in ('dddddddd-4444-4444-8444-444444444444','eeeeeeee-5555-4555-8555-555555555555') and (slot=5 or tournament_id='eeeeeeee-5555-4555-8555-555555555555' or profile_id<>'aaaaaaaa-1111-4111-8111-111111111111')) then raise exception 'Finalized, disabled or unenrolled got a pick'; end if;
 if (select option_id from public.paid_tournament_picks where tournament_id='dddddddd-4444-4444-8444-444444444444' and slot=1 and profile_id='aaaaaaaa-1111-4111-8111-111111111111')<>'away' then raise exception 'Confirmed tournament pick changed'; end if;
 select to_jsonb(p) into before_profile from public.public_profiles p where id='aaaaaaaa-1111-4111-8111-111111111111';
 select count(*) into expected_count from public.predictions g where slot between 0 and 9 and status='open'
 and jsonb_array_length(options)>0 and not exists(select 1 from public.picks p where p.profile_id='aaaaaaaa-1111-4111-8111-111111111111' and p.prediction_day=g.day_id and p.slot=g.slot);
 expected_xp:=public.award_xp((before_profile->>'level')::int,(before_profile->>'xp')::int,expected_count*public.pass_xp(5,'aaaaaaaa-1111-4111-8111-111111111111'));
 update public.daily_bot_settings set enabled=false where singleton;
 state:=public.admin_run_daily_bots_now();
 if (state->>'enabled')::boolean then raise exception 'Manual run left automation active'; end if;
 if (select count(*) from public.picks where profile_id='aaaaaaaa-1111-4111-8111-111111111111' and prediction_day between '2099-10-07' and '2099-10-09')<>4 then raise exception 'Prior date, elapsed deadline or upcoming event missing'; end if;
 if exists(select 1 from public.picks where profile_id='aaaaaaaa-1111-4111-8111-111111111111' and prediction_day='2099-10-08' and slot in (3,4)) then raise exception 'Settling/settled daily event included'; end if;
 if (select option_id from public.picks where profile_id='aaaaaaaa-1111-4111-8111-111111111111' and prediction_day='2099-10-08' and slot=5)<>'b' then raise exception 'Confirmed daily pick changed'; end if;
 if not exists(select 1 from public.public_profiles where id='aaaaaaaa-1111-4111-8111-111111111111' and level=expected_xp[1] and xp=expected_xp[2] and daily_streak_current=1 and last_played_prediction='2099-10-08') then raise exception 'XP or current-date streak incorrect'; end if;
 select to_jsonb(p) into after_profile from public.public_profiles p where id='aaaaaaaa-1111-4111-8111-111111111111';
 perform public.admin_run_daily_bots_now();
 if exists(select 1 from public.public_profiles p where id='aaaaaaaa-1111-4111-8111-111111111111' and to_jsonb(p)<>after_profile) then raise exception 'Replay changed XP or streak'; end if;
 if exists(select 1 from real_bot_profiles_before s join public.public_profiles p using(id) where s.data<>to_jsonb(p)) then raise exception 'Real player stats changed in test'; end if;
 if has_function_privilege('authenticated','public.run_daily_bot_picks()','EXECUTE') or has_function_privilege('anon','public.run_tournament_bot_picks()','EXECUTE') then raise exception 'Private workers exposed'; end if;
 perform set_config('request.jwt.claims','{"email":"ordinary@example.test"}',true);
 begin perform public.admin_run_daily_bots_now(); raise exception 'Non-admin was allowed';
 exception when others then if sqlerrm<>'Somente o proprietário pode administrar bots.' then raise; end if; end;
end;
$$;
select 'PASS: unfinished events across dates/deadlines, tournament enrollment, preserved picks, XP once, manual mode and private access' as result;
