begin;
CREATE OR REPLACE FUNCTION public.interact_level_drop(p_drop_id uuid, p_request_id uuid, p_open boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare target uuid:=public.own_profile_id();d public.level_drops%rowtype; prior jsonb;rar text;choice record;owned boolean;xp_reward integer:=0;progress integer[];player record;opening uuid;response jsonb;
begin
 if p_request_id is null then raise exception 'Identificador obrigatório.'; end if;
 select * into player from public.public_profiles where id=target for update;
 if not found then raise exception 'Perfil não encontrado.'; end if;
 select r.response into prior from public.level_drop_requests r where profile_id=target and request_id=p_request_id;
 if prior is not null then return prior; end if;
 select * into d from public.level_drops where id=p_drop_id and profile_id=target for update;
 if not found then raise exception 'Drop não encontrado.'; end if;
 if d.status='claimed' then return to_jsonb(d); end if;
 if p_open then
  if d.status<>'ready' then raise exception 'Conclua os cliques antes de abrir.'; end if;
  rar:=(array['common','rare','epic','mythic','legendary'])[d.tier+1];
  select c.style,k.kind into choice from public.box_style_catalog c cross join (values ('name'),('frame'),('font')) k(kind) where c.theme='classic' and c.rarity=rar and ((c.item_kind is null and k.kind in ('name','frame')) or c.item_kind=k.kind) order by random() limit 1;
  if not found then raise exception 'Nenhum item disponível nesta raridade.'; end if;
  owned:=exists(select 1 from public.public_profiles where id=target and player_id=1000001) or exists(select 1 from public.box_inventory where profile_id=target and kind=choice.kind and style=choice.style);
  if owned then
   xp_reward:=case rar when 'common' then 25 when 'rare' then 50 when 'epic' then 100 when 'mythic' then 250 else 500 end;
   xp_reward:=public.pass_xp(xp_reward,target); progress:=public.award_xp(player.level,player.xp,xp_reward);
   update public.public_profiles set level=progress[1],xp=progress[2],updated_at=now() where id=target;
  else insert into public.box_inventory(profile_id,kind,style) values(target,choice.kind,choice.style); end if;
  insert into public.box_openings(profile_id,request_id,kind,style,rarity,duplicate,xp_awarded) values(target,d.id,choice.kind,choice.style,rar,owned,xp_reward) returning id into opening;
  update public.level_drops set status='claimed',reward=jsonb_build_object('id',opening,'kind',choice.kind,'style',choice.style,'rarity',rar,'duplicate',owned,'xpAwarded',xp_reward,'balance',0) where id=d.id returning * into d;
 else
  if d.status<>'playing' then raise exception 'Este drop já pode ser aberto.'; end if;
  if d.tier<4 and (('x'||substr(replace(gen_random_uuid()::text,'-',''),1,8))::bit(32)::bigint / 4294967296.0) < public.level_drop_upgrade_chance(d.tier) then
   update public.level_drops set tier=tier+1,clicks_left=case when tier=3 then 1 else 5 end where id=d.id returning * into d;
  else
   update public.level_drops set clicks_left=clicks_left-1,status=case when clicks_left=1 then 'ready' else 'playing' end where id=d.id returning * into d;
  end if;
 end if;
 response:=to_jsonb(d);
 -- A claimed drop is its own permanent replay guard: return its stored reward on retry.
 -- Keep click receipts only while a drop is playing or ready.
 if d.status='claimed' then
  delete from public.level_drop_requests r where r.profile_id=target and r.response->>'id'=d.id::text;
 else
  insert into public.level_drop_requests(profile_id,request_id,response) values(target,p_request_id,response);
 end if;
 return response;
end $function$;
create or replace function public.cleanup_runtime_history() returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare removed_success integer;removed_failure integer;removed_clicks integer;
begin
 -- Never remove executions that are still running.
 delete from cron.job_run_details where status='succeeded' and end_time is not null;
 get diagnostics removed_success=row_count;
 -- Keep only the latest 100 failures, each for no longer than seven days.
 delete from cron.job_run_details where status='failed' and
  (coalesce(end_time,start_time,'-infinity'::timestamptz)<now()-interval '7 days'
   or runid not in (select runid from cron.job_run_details where status='failed'
      order by coalesce(end_time,start_time,'-infinity'::timestamptz) desc,runid desc limit 100));
 get diagnostics removed_failure=row_count;
 -- Live drops keep every receipt; terminal drops already store the final reward.
 delete from public.level_drop_requests r using public.level_drops d
  where d.profile_id=r.profile_id and d.id::text=r.response->>'id' and d.status='claimed';
 get diagnostics removed_clicks=row_count;
 return jsonb_build_object('successfulLogsRemoved',removed_success,'oldOrExcessFailuresRemoved',removed_failure,'closedDropReceiptsRemoved',removed_clicks);
end $$;
revoke all on function public.cleanup_runtime_history() from public,anon,authenticated;
grant execute on function public.cleanup_runtime_history() to service_role;
comment on function public.cleanup_runtime_history() is 'Every 15 minutes: remove success logs and terminal drop receipts; retain at most 100 failed runs for 7 days.';
delete from public.box_style_catalog c where theme='retired'
 and style in ('halloween-house','halloween-graveyard','halloween-bats')
 and not exists(select 1 from public.box_inventory i where i.style=c.style)
 and not exists(select 1 from public.box_openings o where o.style=c.style)
 and not exists(select 1 from public.player_mail m where m.style=c.style)
 and not exists(select 1 from public.public_profiles p where p.pass_name_style=c.style or p.pass_border_style=c.style or p.username_font=c.style);
select public.cleanup_runtime_history() cleanup;
select cron.schedule('runtime-history-cleanup','*/15 * * * *','select public.cleanup_runtime_history();');
notify pgrst,'reload schema';
commit;
select jsonb_build_object('successLogs',(select count(*) from cron.job_run_details where status='succeeded'),'failureLogs',(select count(*) from cron.job_run_details where status='failed'),'closedDropReceipts',(select count(*) from public.level_drop_requests r join public.level_drops d on d.id::text=r.response->>'id' and d.profile_id=r.profile_id where d.status='claimed'),'allDropReceipts',(select count(*) from public.level_drop_requests),'retiredUnusedStyles',(select count(*) from public.box_style_catalog where style in ('halloween-house','halloween-graveyard','halloween-bats')),'cleanupJob',(select jsonb_build_object('active',active,'schedule',schedule) from cron.job where jobname='runtime-history-cleanup')) result;
