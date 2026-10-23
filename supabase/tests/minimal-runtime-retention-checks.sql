-- Execute after the migration, or append to its transaction for a rehearsal. All fixtures roll back.
create function public.runtime_retention_test_failure() returns trigger language plpgsql as $$
begin
 if current_setting('runtime_retention.test_fail',true)='on' then raise exception 'fixture_opening_failure';end if;
 return new;
end $$;
create trigger runtime_retention_test_failure before insert on public.box_openings for each row execute function public.runtime_retention_test_failure();
do $$
declare target uuid:=gen_random_uuid();other uuid:=gen_random_uuid();subject uuid:=gen_random_uuid();other_subject uuid:=gen_random_uuid();drop_id uuid:=gen_random_uuid();other_drop uuid:=gen_random_uuid();
 first_request uuid:=gen_random_uuid();second_request uuid:=gen_random_uuid();open_request uuid:=gen_random_uuid();response jsonb;first_response jsonb;second_response jsonb;claimed_response jsonb;before_profile jsonb;denied boolean;
begin
 insert into public.public_profiles(id,player_id,username,avatar_color) values(target,9900501,'retentionqa1','#3b82f6'),(other,9900502,'retentionqa2','#3b82f6');
 insert into public.private_profiles(profile_id,auth_user_id,email) values(target,subject,'retentionqa1@example.invalid'),(other,other_subject,'retentionqa2@example.invalid');
 -- Owning every candidate makes the XP path deterministic while retaining the real reward selector.
 insert into public.box_inventory(profile_id,kind,style)
 select target,k.kind,c.style from public.box_style_catalog c cross join (values ('name'),('frame'),('font')) k(kind)
 where c.theme='classic' and c.rarity='legendary' and ((c.item_kind is null and k.kind in ('name','frame')) or c.item_kind=k.kind);
 insert into public.level_drops(id,profile_id,milestone,tier,clicks_left,status,received_at) values(drop_id,target,5,4,2,'playing',now()),(other_drop,other,5,4,2,'playing',now());
 perform set_config('request.jwt.claims',jsonb_build_object('sub',subject)::text,true);
 first_response:=public.interact_level_drop(drop_id,first_request,false);
 if first_response->>'clicks_left'<>'1' then raise exception 'First click did not advance';end if;
 response:=public.interact_level_drop(drop_id,first_request,false);
 if response<>first_response then raise exception 'Retry advanced live drop twice';end if;
 perform public.cleanup_runtime_history();
 if not exists(select 1 from public.level_drop_requests where profile_id=target and request_id=first_request) then raise exception 'Live click receipt was removed';end if;
 second_response:=public.interact_level_drop(drop_id,second_request,false);
 if second_response->>'status'<>'ready' then raise exception 'Drop did not become ready';end if;
 perform public.cleanup_runtime_history();
 if public.interact_level_drop(drop_id,second_request,false)<>second_response then raise exception 'Ready receipt replay changed';end if;
 before_profile:=(select to_jsonb(p) from public.public_profiles p where id=target);
 perform set_config('runtime_retention.test_fail','on',true);denied:=false;
 begin perform public.interact_level_drop(drop_id,open_request,true);exception when others then if sqlerrm='fixture_opening_failure' then denied:=true;else raise;end if;end;
 if not denied or (select to_jsonb(p) from public.public_profiles p where id=target)<>before_profile or (select status from public.level_drops where id=drop_id)<>'ready' or (select count(*) from public.level_drop_requests where profile_id=target)<>2 then raise exception 'Failed opening consumed XP, state or receipts';end if;
 perform set_config('runtime_retention.test_fail','off',true);
 claimed_response:=public.interact_level_drop(drop_id,open_request,true);
 if claimed_response->>'status'<>'claimed' or claimed_response->'reward'->>'duplicate'<>'true' or (claimed_response->'reward'->>'xpAwarded')::integer<=0 then raise exception 'Real reward/XP missing';end if;
 if exists(select 1 from public.level_drop_requests where profile_id=target) then raise exception 'Finalized drop kept receipts';end if;
 before_profile:=(select to_jsonb(p) from public.public_profiles p where id=target);
 if public.interact_level_drop(drop_id,open_request,true)<>claimed_response or public.interact_level_drop(drop_id,first_request,false)<>claimed_response or public.interact_level_drop(drop_id,gen_random_uuid(),true)<>claimed_response then raise exception 'Terminal replay did not return stored reward';end if;
 if (select count(*) from public.box_openings where profile_id=target)<>1 or (select to_jsonb(p) from public.public_profiles p where id=target)<>before_profile then raise exception 'Terminal replay credited twice';end if;
 denied:=false;
 begin perform public.interact_level_drop(other_drop,gen_random_uuid(),false);exception when others then if sqlerrm='Drop não encontrado.' then denied:=true;else raise;end if;end;
 if not denied then raise exception 'Cross-profile drop was accessed';end if;
 if has_function_privilege('authenticated','public.cleanup_runtime_history()','execute') or has_function_privilege('anon','public.cleanup_runtime_history()','execute') or not has_function_privilege('service_role','public.cleanup_runtime_history()','execute') then raise exception 'Cleanup privileges incorrect';end if;
 if exists(select 1 from public.box_style_catalog where style in ('halloween-house','halloween-graveyard','halloween-bats')) then raise exception 'Unused retired entries remain';end if;
end $$;
-- Synthetic cron rows verify the retention cap, age limit and active-run exclusion.
insert into cron.job_run_details(jobid,runid,username,command,status,start_time,end_time)
 select (select min(jobid) from cron.job),-1000000-n,current_user,'retention-fixture','failed',now()-n*interval '1 minute',now()-n*interval '1 minute' from generate_series(1,105) n;
insert into cron.job_run_details(jobid,runid,username,command,status,start_time,end_time) values
 ((select min(jobid) from cron.job),-1000200,current_user,'retention-fixture','failed',now()-interval '8 days',now()-interval '8 days'),
 ((select min(jobid) from cron.job),-1000201,current_user,'retention-fixture','succeeded',now()-interval '1 minute',now()),
 ((select min(jobid) from cron.job),-1000202,current_user,'retention-fixture','running',now(),null);
select public.cleanup_runtime_history();
do $$begin
 if (select count(*) from cron.job_run_details where status='failed')<>100 then raise exception 'Failed log cap not enforced';end if;
 if exists(select 1 from cron.job_run_details where status='failed' and coalesce(end_time,start_time)<now()-interval '7 days') then raise exception 'Expired failure log retained';end if;
 if exists(select 1 from cron.job_run_details where runid in (-1000200,-1000201)) or not exists(select 1 from cron.job_run_details where runid=-1000202 and status='running') then raise exception 'Cron status retention incorrect';end if;
end $$;
select jsonb_build_object('passed',true,'checks','live click retries, active and ready receipt retention, finalized cache deletion, replay without double XP/reward, atomic failure rollback, cross-profile isolation, cleanup permissions, unused catalog removal, capped recent failures, successful log removal, active executions preserved') retention_test;
rollback;
