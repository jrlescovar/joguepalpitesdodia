-- Run after the migration inside a transaction ending in ROLLBACK.
select pg_advisory_xact_lock(hashtextextended('daily-bot-picks',0));
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
insert into public.paid_tournament_predictions(tournament_id,slot,match_day,home_team,away_team,title,closes_at,status,winning_option_id,settled_at)
select 'dddddddd-4444-4444-8444-444444444444',slot::smallint,(deadline at time zone 'America/Sao_Paulo')::date,'Casa QA','Fora QA','Quem terá mais cartões?',deadline,
 case when slot=5 then 'settled' else 'open' end,case when slot=5 then 'home' end,case when slot=5 then now() end
from (values(1,clock_timestamp()+interval '1 hour'),(2,clock_timestamp()+interval '2 hours'),(3,clock_timestamp()+interval '1 day'),(4,clock_timestamp()-interval '1 hour'),(5,clock_timestamp()+interval '2 hours')) v(slot,deadline);
insert into public.paid_tournament_predictions(tournament_id,slot,match_day,home_team,away_team,closes_at)
values('eeeeeeee-5555-4555-8555-555555555555',1,((clock_timestamp()+interval '1 hour') at time zone 'America/Sao_Paulo')::date,'Casa QA','Fora QA',clock_timestamp()+interval '1 hour');
insert into public.paid_tournament_picks(tournament_id,slot,profile_id,option_id)
values('dddddddd-4444-4444-8444-444444444444',1,'aaaaaaaa-1111-4111-8111-111111111111','away');

do $$
declare result jsonb;
begin
 if public.run_tournament_bot_picks()<>0 then raise exception 'Paused bots submitted tournament picks'; end if;
 update public.daily_bot_settings set enabled=true where singleton;
 if public.run_tournament_bot_picks()<>2 then raise exception 'Wrong eligible picks count'; end if;
 if public.run_tournament_bot_picks()<>0 then raise exception 'Repeat duplicated picks'; end if;
 if (select option_id from public.paid_tournament_picks where tournament_id='dddddddd-4444-4444-8444-444444444444' and slot=1 and profile_id='aaaaaaaa-1111-4111-8111-111111111111')<>'away' then raise exception 'Manual pick changed'; end if;
 if exists(select 1 from public.paid_tournament_picks where tournament_id in ('dddddddd-4444-4444-8444-444444444444','eeeeeeee-5555-4555-8555-555555555555') and (slot in (4,5) or tournament_id='eeeeeeee-5555-4555-8555-555555555555' or profile_id<>'aaaaaaaa-1111-4111-8111-111111111111')) then raise exception 'Ineligible match or account received picks'; end if;
 if exists(select 1 from public.tournament_bot_pick_log where tournament_id='dddddddd-4444-4444-8444-444444444444' and slot=1) then raise exception 'Manual pick adopted into bot audit'; end if;
 if exists(select 1 from public.paid_tournament_picks where option_id not in ('home','draw','away')) then raise exception 'Invalid option'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'email',(select owner_email from public.app_config where singleton))::text,true);
 result:=public.get_admin_daily_bots();
 if not exists(select 1 from jsonb_array_elements(result->'accounts') a where (a->>'playerId')::integer=9900101 and (a->>'tournamentPicks')::integer=3 and (a->>'tournamentTotal')::integer=5) then raise exception 'Panel tournament progress wrong'; end if;
 update public.daily_bot_settings set enabled=false where singleton;
 insert into public.paid_tournament_predictions(tournament_id,slot,match_day,home_team,away_team,closes_at) values('dddddddd-4444-4444-8444-444444444444',6,((clock_timestamp()+interval '1 hour') at time zone 'America/Sao_Paulo')::date,'Casa QA','Fora QA',clock_timestamp()+interval '1 hour');
 if public.run_tournament_bot_picks()<>0 then raise exception 'Pause ignored'; end if;
 update public.daily_bot_settings set enabled=true where singleton;
 perform public.run_daily_bot_picks();
 if not exists(select 1 from public.tournament_bot_pick_log where tournament_id='dddddddd-4444-4444-8444-444444444444' and slot=6) then raise exception 'Minute worker did not include tournaments'; end if;
 insert into public.paid_tournament_entries(tournament_id,profile_id,registration_source) values('dddddddd-4444-4444-8444-444444444444','bbbbbbbb-2222-4222-8222-222222222222','admin');
 if public.run_tournament_bot_picks()<>4 then raise exception 'New enrolled bot did not receive eligible picks'; end if;
 delete from public.daily_bot_accounts where profile_id='aaaaaaaa-1111-4111-8111-111111111111';
 insert into public.paid_tournament_predictions(tournament_id,slot,match_day,home_team,away_team,closes_at) values('dddddddd-4444-4444-8444-444444444444',7,((clock_timestamp()+interval '1 hour') at time zone 'America/Sao_Paulo')::date,'Casa QA','Fora QA',clock_timestamp()+interval '1 hour');
 if public.run_tournament_bot_picks()<>1 then raise exception 'Removed bot received picks'; end if;
 if exists(select 1 from tournament_bot_profile_snapshot s join public.public_profiles p using(id) where s.data<>to_jsonb(p)) then raise exception 'Tournament picks changed global profile stats'; end if;
 if exists(select 1 from public.picks where profile_id in ('aaaaaaaa-1111-4111-8111-111111111111','bbbbbbbb-2222-4222-8222-222222222222','cccccccc-3333-4333-8333-333333333333')) then raise exception 'Global picks created'; end if;
 if has_function_privilege('authenticated','public.run_tournament_bot_picks()','EXECUTE') or has_function_privilege('anon','public.run_tournament_bot_picks()','EXECUTE') or has_function_privilege('service_role','public.run_tournament_bot_picks()','EXECUTE') then raise exception 'Worker exposed'; end if;
 if has_table_privilege('authenticated','public.tournament_bot_pick_log','SELECT') then raise exception 'Audit exposed'; end if;
 if not exists(select 1 from cron.job where jobname='daily-bot-picks' and active and schedule='* * * * *') then raise exception 'Minute scheduler missing'; end if;
end;
$$;
select 'PASS: tournament bots eligibility, future published games, preservation, pause, enrollment, removal, integration, private access and global stats' as result;

