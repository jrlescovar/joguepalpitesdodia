-- Run with the migration inside BEGIN/ROLLBACK. Fixtures never persist.
select pg_advisory_xact_lock(hashtextextended('daily-bot-picks',0));
create temporary table batch_real_profiles as select id,to_jsonb(p) data from public.public_profiles p;
create temporary table batch_real_picks as select profile_id,prediction_day,slot,to_jsonb(p) data from public.picks p;
delete from public.daily_bot_accounts;
update public.daily_bot_settings set enabled=false where singleton;
insert into public.public_profiles(id,player_id,username,avatar_color)
values('aaaaaa16-0000-4000-8000-000000000001',9901601,'batchqa1','#22c55e'),
 ('aaaaaa16-0000-4000-8000-000000000002',9901602,'batchqa2','#22c55e');
insert into public.daily_bot_accounts(profile_id) values('aaaaaa16-0000-4000-8000-000000000001'),('aaaaaa16-0000-4000-8000-000000000002');
create or replace function public.wheel_random_index(p_count integer) returns integer language sql volatile as $$select p_count/2;$$;
insert into public.predictions(day_id,slot,title,options,closes_at,status)
select '2000-01-02',s::smallint,'Bounded bots QA',opts::jsonb,now()-interval '1 day',state
from (values
 (0,'[{"id":"none","label":"Nenhum","rankPoints":360},{"id":"home","label":"Casa","rankPoints":30},{"id":"away","label":"Fora","rankPoints":30}]','open'),
 (1,'[{"id":"over","label":"Acima","rankPoints":151},{"id":"limit","label":"Limite","rankPoints":150}]','open'),
 (2,'[{"id":"over","label":"Acima","rankPoints":151},{"id":"none","label":"Nenhum","rankPoints":360}]','open'),
 (3,'[{"id":"a","label":"Casa","rankPoints":30},{"id":"b","label":"Fora","rankPoints":30}]','settled'))v(s,opts,state);
do $$begin
 if public.run_daily_bot_picks_batch(3)<>0 then raise exception 'Paused worker ran'; end if;
 update public.daily_bot_settings set enabled=true where singleton;
 if public.run_daily_bot_picks_batch(3)<>3 then raise exception 'First batch exceeded/ignored limit'; end if;
 if public.run_daily_bot_picks_batch(1)<>1 then raise exception 'Resume failed'; end if;
 if exists(select 1 from public.picks where prediction_day='2000-01-02' and (option_id in ('none','over') or slot in (2,3))) then raise exception 'Forbidden/settled pick'; end if;
 if (select count(distinct option_id) from public.picks where prediction_day='2000-01-02' and slot=0)<>2 then raise exception 'Diversity lost across batches'; end if;
 if public.run_daily_bot_picks_batch(0)<>0 then raise exception 'Zero budget ran'; end if;
end;$$;
insert into public.paid_tournaments(id,name,metric,starts_at,ends_at,entry_cents,prize_cents,prediction_count,prize_mode,enabled)
values('aaaaaa16-0000-4000-8000-000000000100','Bounded QA','mixed','2099-01-01T12:00:00-03:00','2099-01-02T00:00:00-03:00',100,0,20,'entries',true);
insert into public.paid_tournament_predictions(tournament_id,slot,match_day,home_team,away_team,title,competition,closes_at,options,rules)
select 'aaaaaa16-0000-4000-8000-000000000100',s::smallint,'2099-01-01','Casa','Fora','QA binary','QA','2099-01-01T12:00:00-03:00',
 '[{"id":"home","label":"Sim"},{"id":"away","label":"Não"}]'::jsonb,'QA binary choices.' from generate_series(1,2)s;
insert into public.paid_tournament_entries(tournament_id,profile_id,registration_source)
values('aaaaaa16-0000-4000-8000-000000000100','aaaaaa16-0000-4000-8000-000000000001','admin');
create temporary table batch_profiles_after_daily as select id,to_jsonb(p) data from public.public_profiles p;
do $$begin
 if public.run_tournament_bot_picks_batch(1)<>1 or public.run_tournament_bot_picks_batch(15)<>1 or public.run_tournament_bot_picks_batch(15)<>0 then raise exception 'Tournament limit/resume/replay failed'; end if;
 if exists(select 1 from public.paid_tournament_picks where tournament_id='aaaaaa16-0000-4000-8000-000000000100' and (option_id='draw' or profile_id<>'aaaaaa16-0000-4000-8000-000000000001')) then raise exception 'Invalid option or unenrolled bot played'; end if;
 if exists(select 1 from batch_profiles_after_daily s join public.public_profiles p using(id) where s.data<>to_jsonb(p)) then raise exception 'Tournament/replay awarded XP'; end if;
end;$$;
delete from public.daily_bot_accounts;
select set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'email',(select owner_email from public.app_config where singleton))::text,true);
do $$declare value jsonb;begin
 value:=public.admin_run_bot_pick_batch(true);
 if (value->>'enabled')::boolean or (value->>'hasMore')::boolean or (value->>'batchCreated')::int<>0 then raise exception 'Manual completion state incorrect'; end if;
 if has_function_privilege('anon','public.admin_run_bot_pick_batch(boolean)','EXECUTE') or has_function_privilege('authenticated','public.run_daily_bot_picks_batch(integer)','EXECUTE') or has_function_privilege('authenticated','public.run_tournament_bot_picks_batch(integer)','EXECUTE') then raise exception 'Private worker exposed'; end if;
end;$$;
select set_config('request.jwt.claims','{"email":"ordinary@example.test"}',true);
do $$declare denied boolean:=false;begin
 begin perform public.admin_run_bot_pick_batch(true); exception when others then denied:=true; end;
 if not denied then raise exception 'Non-admin ran bots'; end if;
 if exists(select 1 from batch_real_profiles s join public.public_profiles p using(id) where s.data<>to_jsonb(p)) or exists(select 1 from batch_real_picks s join public.picks p using(profile_id,prediction_day,slot) where s.data<>to_jsonb(p)) then raise exception 'Real data changed'; end if;
end;$$;
select 'PASS: bounded writes; resume; 150 ceiling; diversity; settled skip; binary markets; enrollment; replay; manual mode; ACL; real players unchanged' as result;
