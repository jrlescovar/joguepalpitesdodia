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
notify pgrst,'reload schema';
commit;
select jsonb_build_object(
 'pendingMessages',(select count(*) from public.player_mail),
 'receivedMailRows',(select count(*) from public.player_mail where received_at is not null),
 'expiredMailRows',(select count(*) from public.player_mail where created_at<=now()-interval '7 days'),
 'oldPendingDropRows',(select count(*) from public.level_drops where received_at is null and status<>'claimed'),
 'cleanupActive',(select active from cron.job where jobname='mailbox-retention-cleanup')
) mail_retention_report;
