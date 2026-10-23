begin;
-- Specific frame gifts use the same seven-day retention and atomic claim as boxes.
alter table public.player_mail add column style text references public.box_style_catalog(style);
alter table public.player_mail drop constraint player_mail_kind_check;
alter table public.player_mail add constraint player_mail_kind_check
 check(kind in ('drop','classic','font','halloween','premium','frame'));
alter table public.player_mail add constraint player_mail_frame_payload_check
 check((kind='frame' and style is not null and quantity=1) or (kind<>'frame' and style is null));
create unique index player_mail_pending_frame on public.player_mail(profile_id,style) where kind='frame';

create or replace function public.get_mailbox() returns jsonb
language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); result jsonb;
begin
 perform public.ensure_level_drop_mail(target);
 select coalesce(jsonb_agg(
  case when kind='frame' then jsonb_build_object('kind','frame:'||style,'style',style,'quantity',quantity)
  else jsonb_build_object('kind',kind,'quantity',quantity) end order by kind,style),'[]'::jsonb) into result
 from(select kind,style,sum(quantity)::integer quantity from public.player_mail
 where profile_id=target and received_at is null and created_at>now()-interval '7 days' group by kind,style) groups;
 return result;
end $$;

create or replace function public.receive_mail(p_kind text) returns void
language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); quantity integer; sender uuid; balance_table text;
begin
 if p_kind is null or (p_kind not in ('drop','classic','font','halloween','premium') and p_kind not like 'frame:%') then raise exception 'Entrega inválida.'; end if;
 perform public.ensure_level_drop_mail(target);
 if p_kind like 'frame:%' then
  -- Only a pending delivery owned by this player can unlock the specific frame.
  with received as (
   delete from public.player_mail where profile_id=target and kind='frame'
   and style=substring(p_kind from 7) and received_at is null
   and created_at>now()-interval '7 days' returning style
  ) insert into public.box_inventory(profile_id,kind,style)
    select target,'frame',style from received on conflict do nothing;
  return;
 end if;
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


create function public.admin_grant_frame_mail(p_profile_id uuid,p_style text) returns jsonb
language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare granted integer;
begin
 if auth.uid() is null or not public.is_admin() then raise exception 'Acesso restrito.'; end if;
 perform 1 from public.public_profiles where id=p_profile_id for update;
 if not found then raise exception 'Jogador não encontrado.'; end if;
 if not exists(select 1 from public.box_style_catalog where style=p_style and (item_kind is null or item_kind='frame')) then
  raise exception 'Moldura inválida.';
 end if;
 perform public.cleanup_player_mail(p_profile_id);
 if exists(select 1 from public.box_inventory where profile_id=p_profile_id and kind='frame' and style=p_style) then
  return jsonb_build_object('alreadyOwned',true,'queued',false);
 end if;
 insert into public.player_mail(profile_id,kind,quantity,style,granted_by)
 values(p_profile_id,'frame',1,p_style,auth.uid()) on conflict(profile_id,style) where kind='frame' do nothing;
 get diagnostics granted=row_count;
 return jsonb_build_object('alreadyOwned',false,'queued',granted=1,'pending',true);
end $$;
revoke all on function public.admin_grant_frame_mail(uuid,text) from public,anon;
grant execute on function public.admin_grant_frame_mail(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
