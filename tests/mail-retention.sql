begin;
-- A single checkpoint per player prevents expired level rewards from being reissued.
create table public.level_drop_mail_progress(
 profile_id uuid primary key references public.public_profiles(id) on delete cascade,
 issued_through integer not null default 0 check(issued_through>=0 and issued_through%5=0)
);
alter table public.level_drop_mail_progress enable row level security;
revoke all on public.level_drop_mail_progress from public,anon,authenticated;

-- Serialize the conversion with claims and level changes.
lock table public.public_profiles,public.player_mail,public.level_drops in share row exclusive mode;
insert into public.level_drop_mail_progress(profile_id,issued_through)
select p.id,coalesce(max(d.milestone),0) from public.public_profiles p
left join public.level_drops d on d.profile_id=p.id group by p.id;
-- Preserve the original delivery time: migration never renews the seven-day period.
insert into public.player_mail(profile_id,kind,quantity,created_at)
select profile_id,'drop',1,created_at from public.level_drops
where received_at is null and status<>'claimed';
delete from public.level_drops where received_at is null and status<>'claimed';
create index player_mail_expiration on public.player_mail(created_at);

create function public.cleanup_player_mail(p_profile_id uuid default null) returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare removed integer;
begin
 delete from public.player_mail
 where (p_profile_id is null or profile_id=p_profile_id)
 and (received_at is not null or created_at<=now()-interval '7 days');
 get diagnostics removed=row_count;
 return removed;
end $$;
revoke all on function public.cleanup_player_mail(uuid) from public,anon,authenticated;

create function public.ensure_level_drop_mail(p_profile_id uuid) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare current_level integer; issued integer; reached integer;
begin
 select level into current_level from public.public_profiles where id=p_profile_id for update;
 if not found then raise exception 'Perfil não encontrado.'; end if;
 insert into public.level_drop_mail_progress(profile_id) values(p_profile_id) on conflict do nothing;
 select issued_through into issued from public.level_drop_mail_progress where profile_id=p_profile_id for update;
 reached:=(current_level/5)*5;
 if reached>issued then
  insert into public.player_mail(profile_id,kind,quantity) values(p_profile_id,'drop',(reached-issued)/5);
  update public.level_drop_mail_progress set issued_through=reached where profile_id=p_profile_id;
 end if;
 perform public.cleanup_player_mail(p_profile_id);
end $$;
revoke all on function public.ensure_level_drop_mail(uuid) from public,anon,authenticated;

create or replace function public.get_level_drops() returns jsonb
language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); lvl integer;
begin
 perform public.ensure_level_drop_mail(target);
 select level into lvl from public.public_profiles where id=target;
 return jsonb_build_object('level',lvl,'drops',coalesce((select jsonb_agg(to_jsonb(d) order by created_at,milestone) from public.level_drops d where profile_id=target),'[]'::jsonb));
end $$;

create or replace function public.get_mailbox() returns jsonb
language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); result jsonb;
begin
 perform public.ensure_level_drop_mail(target);
 select coalesce(jsonb_agg(jsonb_build_object('kind',kind,'quantity',quantity) order by kind),'[]'::jsonb) into result
 from(select kind,sum(quantity)::integer quantity from public.player_mail
 where profile_id=target and received_at is null and created_at>now()-interval '7 days' group by kind)groups;
 return result;
end $$;

create or replace function public.receive_mail(p_kind text) returns void
language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); quantity integer; sender uuid; balance_table text;
begin
 if p_kind is null or p_kind not in ('drop','classic','font','halloween','premium') then raise exception 'Entrega inválida.'; end if;
 perform public.ensure_level_drop_mail(target);
 -- Removal and inventory credit commit together; retries cannot credit a second time.
 with received as (
  delete from public.player_mail where profile_id=target and kind=p_kind
  and received_at is null and created_at>now()-interval '7 days' returning *
 )select coalesce(sum(r.quantity),0)::integer,(array_agg(r.granted_by))[1] into quantity,sender from received r;
 if p_kind='drop' then
  insert into public.level_drops(profile_id,milestone,received_at) select target,0,now() from generate_series(1,quantity);
 elsif p_kind in ('classic','font','halloween') then
  balance_table:=case p_kind when 'classic' then 'box_balances' when 'font' then 'font_box_balances' else 'halloween_box_balances' end;
  if quantity>0 then execute format('insert into public.%I(profile_id,balance) values($1,$2) on conflict(profile_id) do update set balance=public.%I.balance+excluded.balance',balance_table,balance_table) using target,quantity; end if;
 elsif p_kind='premium' then
  if quantity>0 then insert into public.pass_grants(profile_id,grant_ends_at,granted_by) values(target,now()+make_interval(days=>quantity),sender)
  on conflict(profile_id) do update set grant_ends_at=greatest(now(),public.pass_grants.grant_ends_at)+make_interval(days=>quantity),revoked_at=null,granted_by=excluded.granted_by,updated_at=now(); end if;
 end if;
end $$;

-- Keep the legacy grouped claim endpoint consistent with mailbox deletion.
create or replace function public.receive_all_level_drops() returns integer
language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); before_count integer; after_count integer;
begin
 if target is null then raise exception 'Perfil não encontrado.'; end if;
 perform 1 from public.public_profiles where id=target for update;
 select count(*) into before_count from public.level_drops where profile_id=target;
 perform public.receive_mail('drop');
 select count(*) into after_count from public.level_drops where profile_id=target;
 return after_count-before_count;
end $$;

do $$ declare definition text; revised text; begin
 definition:=pg_get_functiondef('public.admin_set_pass_grant(uuid,integer)'::regprocedure);
 revised:=replace(definition,'update public.player_mail set received_at=now() where profile_id=p_profile_id and kind=''premium'' and received_at is null;', 'delete from public.player_mail where profile_id=p_profile_id and kind=''premium'';');
 if revised=definition then raise exception 'Expected Premium mail cancellation not found';end if;
 execute revised;
end $$;
-- New functions are private; existing player RPC grants remain unchanged.
select public.cleanup_player_mail();
-- Generate any just-reached milestones while preserving prior issued checkpoints.
do $$ declare player record; begin
 for player in select id from public.public_profiles loop perform public.ensure_level_drop_mail(player.id); end loop;
end $$;
select cron.schedule('mailbox-retention-cleanup','* * * * *','select public.cleanup_player_mail();');

create function public.mail_test_credit_guard() returns trigger language plpgsql as $$begin
 if current_setting('mail.test_fail',true)='on' and new.profile_id=current_setting('mail.test_profile')::uuid then raise exception 'test_credit_failure';end if;
 return new;
end $$;
create trigger mail_test_credit_guard before insert or update on public.box_balances for each row execute function public.mail_test_credit_guard();
create or replace function public.is_admin() returns boolean language sql stable as $$select true$$;
do $$
declare target uuid; subject uuid; other uuid; old_balance integer; old_days timestamptz; after_days timestamptz;
 before_drops integer; quantity integer; checkpoint integer; item record; expected integer; failed boolean:=false;
begin
 select p.id,q.auth_user_id into target,subject from public.public_profiles p join public.private_profiles q on q.profile_id=p.id where p.player_id<>1000001 and q.auth_user_id is not null order by p.player_id limit 1;
 select id into other from public.public_profiles where id<>target limit 1;
 if target is null then raise exception 'Test player missing';end if;
 perform set_config('request.jwt.claim.sub',subject::text,true);
 perform set_config('mail.test_profile',target::text,true);
 delete from public.player_mail where profile_id=target;
 perform public.ensure_level_drop_mail(target);
 delete from public.player_mail where profile_id=target;
 insert into public.player_mail(profile_id,kind,quantity,created_at) values
 (target,'drop',3,now()),(target,'drop',4,now()-interval '7 days'),
 (target,'classic',2,now()),(target,'classic',5,now()-interval '7 days'),
 (target,'font',3,now()),(target,'halloween',4,now()),(target,'premium',2,now());
 if jsonb_array_length(public.get_mailbox())<>5 then raise exception 'Grouped mailbox kinds mismatch';end if;
 if exists(select 1 from public.player_mail where profile_id=target and created_at<=now()-interval '7 days') then raise exception 'Exact seven-day boundary not purged';end if;
 if (select (r->>'quantity')::integer from jsonb_array_elements(public.get_mailbox())r where r->>'kind'='drop')<>3 then raise exception 'Expired gifts included';end if;
 for item in select * from(values('classic','box_balances',2),('font','font_box_balances',3),('halloween','halloween_box_balances',4))x(kind,table_name,amount) loop
  execute format('select coalesce((select balance from public.%I where profile_id=$1),0)',item.table_name) into old_balance using target;
  perform public.receive_mail(item.kind);
  execute format('select balance from public.%I where profile_id=$1',item.table_name) into quantity using target;
  if quantity<>old_balance+item.amount then raise exception 'Mail credit mismatch for %',item.kind;end if;
  if exists(select 1 from public.player_mail where profile_id=target and kind=item.kind) then raise exception 'Claimed mail not deleted for %',item.kind;end if;
  perform public.receive_mail(item.kind);
  execute format('select balance from public.%I where profile_id=$1',item.table_name) into quantity using target;
  if quantity<>old_balance+item.amount then raise exception 'Claim replay credited twice';end if;
 end loop;
 select count(*) into before_drops from public.level_drops where profile_id=target;
 perform public.receive_mail('drop');
 if (select count(*) from public.level_drops where profile_id=target)<>before_drops+3 then raise exception 'Drop claim quantity incorrect';end if;
 if exists(select 1 from public.player_mail where profile_id=target and kind='drop') then raise exception 'Drop mail retained after claim';end if;
 perform public.receive_mail('drop');
 if (select count(*) from public.level_drops where profile_id=target)<>before_drops+3 then raise exception 'Drop replay credited twice';end if;
 update public.level_drops set created_at=now()-interval '8 days' where profile_id=target and received_at is not null;
 perform public.cleanup_player_mail(target);
 if (select count(*) from public.level_drops where profile_id=target)<>before_drops+3 then raise exception 'Received inventory was deleted with mail';end if;
 select grant_ends_at into old_days from public.pass_grants where profile_id=target;
 perform public.receive_mail('premium');
 select grant_ends_at into after_days from public.pass_grants where profile_id=target;
 if after_days<>greatest(now(),coalesce(old_days,now()))+interval '2 days' then raise exception 'Premium delivery mismatch';end if;
 perform public.receive_mail('premium');
 if (select grant_ends_at from public.pass_grants where profile_id=target)<>after_days then raise exception 'Premium replay extended twice';end if;
 if exists(select 1 from public.player_mail where profile_id=target) then raise exception 'Received messages left behind';end if;
 -- Expiring a milestone removes the message and permanently advances its issuance checkpoint.
 select issued_through into checkpoint from public.level_drop_mail_progress where profile_id=target;
 update public.public_profiles set level=checkpoint+4 where id=target;
 if public.get_mailbox()<>'[]'::jsonb then raise exception 'Milestone issued before level multiple of five';end if;
 update public.public_profiles set level=checkpoint+5 where id=target;
 if (select (r->>'quantity')::integer from jsonb_array_elements(public.get_mailbox())r where r->>'kind'='drop')<>1 then raise exception 'New milestone mail missing';end if;
 update public.player_mail set created_at=now()-interval '7 days' where profile_id=target and kind='drop';
 perform public.receive_mail('drop');
 perform public.get_level_drops();perform public.get_mailbox();perform public.get_mailbox();
 if exists(select 1 from public.player_mail where profile_id=target) then raise exception 'Expired milestone regenerated';end if;
 if (select count(*) from public.level_drops where profile_id=target)<>before_drops+3 then raise exception 'Expired milestone was credited';end if;
 update public.public_profiles set level=checkpoint+10 where id=target;
 if public.receive_all_level_drops()<>1 then raise exception 'Next milestone or legacy grouped claim broken';end if;
 if public.receive_all_level_drops()<>0 then raise exception 'Legacy claim replay duplicated reward';end if;
 -- Cleanup on one mailbox is scoped; the scheduled sweep covers everyone.
 insert into public.player_mail(profile_id,kind,quantity,created_at)values(other,'classic',1,now()-interval '8 days');
 perform public.get_mailbox();
 if not exists(select 1 from public.player_mail where profile_id=other and created_at<=now()-interval '7 days') then raise exception 'Player cleanup touched another mailbox';end if;
 perform public.cleanup_player_mail();
 if exists(select 1 from public.player_mail where created_at<=now()-interval '7 days' or received_at is not null) then raise exception 'Global cleanup incomplete';end if;
 -- A failed inventory write must roll back mail deletion too.
 select coalesce((select balance from public.box_balances where profile_id=target),0) into old_balance;
 insert into public.player_mail(profile_id,kind,quantity)values(target,'classic',7);
 perform set_config('mail.test_fail','on',true);
 begin perform public.receive_mail('classic');exception when others then if sqlerrm<>'test_credit_failure' then raise;end if;failed:=true;end;
 if not failed or not exists(select 1 from public.player_mail m where m.profile_id=target and m.kind='classic' and m.quantity=7) then raise exception 'Failed credit lost mail';end if;
 if (select balance from public.box_balances where profile_id=target)<>old_balance then raise exception 'Failed credit changed inventory';end if;
 perform set_config('mail.test_fail','off',true);perform public.receive_mail('classic');
 if (select balance from public.box_balances where profile_id=target)<>old_balance+7 then raise exception 'Retry did not deliver preserved mail';end if;
 perform public.admin_set_pass_grant(target,5);perform public.admin_set_pass_grant(target,0);
 if exists(select 1 from public.player_mail where profile_id=target and kind='premium') then raise exception 'Cancelled Premium message kept in database';end if;
 if has_function_privilege('authenticated','public.cleanup_player_mail(uuid)','EXECUTE') or has_function_privilege('authenticated','public.ensure_level_drop_mail(uuid)','EXECUTE') or has_table_privilege('authenticated','public.level_drop_mail_progress','UPDATE') then raise exception 'Private cleanup permissions exposed';end if;
 if not has_function_privilege('authenticated','public.get_mailbox()','EXECUTE') then raise exception 'Player mailbox permission removed';end if;
end $$;
rollback;
select 'PASS seven-day boundary, deletion at all five claims, replay protection, inventory preservation, expired milestones never reissued, future milestones, scoped/global sweep, failed-credit rollback and private permissions; test changes rolled back' result;
