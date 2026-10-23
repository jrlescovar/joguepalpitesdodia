begin;
delete from public.level_drop_xp_repairs r using public.level_drops d where r.drop_id=d.id and d.drop_kind='normal';
delete from public.level_drop_requests r where r.response->>'drop_kind' is distinct from 'legendary';
delete from public.level_drops where drop_kind='normal';
delete from public.player_mail where kind='drop';
CREATE OR REPLACE FUNCTION public.get_level_drops()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare target uuid:=public.own_profile_id(); lvl integer;
begin
 perform public.cleanup_player_mail(target);
 select level into lvl from public.public_profiles where id=target;
 return jsonb_build_object('level',lvl,'drops',coalesce((select jsonb_agg(to_jsonb(d) order by created_at,milestone) from public.level_drops d where profile_id=target and drop_kind='legendary'),'[]'::jsonb));
end $function$
;
CREATE OR REPLACE FUNCTION public.get_mailbox()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare target uuid:=public.own_profile_id(); result jsonb;
begin
 perform public.cleanup_player_mail(target);
 select coalesce(jsonb_agg(
  case when kind='frame' then jsonb_build_object('kind','frame:'||style,'style',style,'quantity',quantity)
  else jsonb_build_object('kind',kind,'quantity',quantity) end order by kind,style),'[]'::jsonb) into result
 from(select kind,style,sum(quantity)::integer quantity from public.player_mail
 where profile_id=target and received_at is null and created_at>now()-interval '7 days' group by kind,style) groups;
 return result;
end $function$
;
CREATE OR REPLACE FUNCTION public.receive_mail(p_kind text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare target uuid:=public.own_profile_id(); quantity integer; sender uuid; balance_table text;
begin
 if p_kind='drop' then raise exception 'O drop de nível foi removido.';end if;
 if p_kind is null or (p_kind not in ('drop','legendary_drop','classic','font','halloween','premium') and p_kind not like 'frame:%') then raise exception 'Entrega inválida.'; end if;
 perform public.cleanup_player_mail(target);
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
 if p_kind='legendary_drop' then
  insert into public.level_drops(profile_id,milestone,received_at,drop_kind,tier,clicks_left,status) select target,0,now(),'legendary',4,0,'ready' from generate_series(1,quantity);
 elsif p_kind in ('classic','font','halloween') then
  balance_table:=case p_kind when 'classic' then 'box_balances' when 'font' then 'font_box_balances' else 'halloween_box_balances' end;
  if quantity>0 then execute format('insert into public.%I(profile_id,balance) values($1,$2) on conflict(profile_id) do update set balance=public.%I.balance+excluded.balance',balance_table,balance_table) using target,quantity; end if;
 elsif p_kind='premium' then
  if quantity>0 then insert into public.pass_grants(profile_id,grant_ends_at,granted_by) values(target,now()+make_interval(days=>quantity),sender)
  on conflict(profile_id) do update set grant_ends_at=greatest(now(),public.pass_grants.grant_ends_at)+make_interval(days=>quantity),revoked_at=null,granted_by=excluded.granted_by,updated_at=now(); end if;
 end if;
end $function$
;
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
 if not found then raise exception 'Caixa não encontrada.'; end if;
 if d.drop_kind<>'legendary' then raise exception 'O drop de nível foi removido.'; end if;
 if d.received_at is null then raise exception 'Receba a caixa no correio antes de abrir.'; end if;
 if d.status='claimed' then return to_jsonb(d); end if;
 if not p_open then raise exception 'Use Abrir caixa.';end if;
  if d.status<>'ready' then raise exception 'Caixa indisponível.'; end if;
  rar:='legendary';
  select c.style,k.kind into choice from public.box_style_catalog c cross join (values ('name'),('frame'),('font')) k(kind) where c.theme='classic' and c.rarity=rar and ((c.item_kind is null and k.kind in ('name','frame')) or c.item_kind=k.kind) order by random() limit 1;
  if not found then raise exception 'Nenhum item disponível nesta raridade.'; end if;
  owned:=exists(select 1 from public.public_profiles where id=target and player_id=1000001) or exists(select 1 from public.box_inventory where profile_id=target and kind=choice.kind and style=choice.style);
  if owned then
   xp_reward:=1000;
   xp_reward:=public.pass_xp(xp_reward,target); progress:=public.award_xp(player.level,player.xp,xp_reward);
   update public.public_profiles set level=progress[1],xp=progress[2],updated_at=now() where id=target;
  else insert into public.box_inventory(profile_id,kind,style) values(target,choice.kind,choice.style); end if;
  insert into public.box_openings(profile_id,request_id,kind,style,rarity,duplicate,xp_awarded) values(target,d.id,choice.kind,choice.style,rar,owned,xp_reward) returning id into opening;
  update public.level_drops set status='claimed',reward=jsonb_build_object('id',opening,'kind',choice.kind,'style',choice.style,'rarity',rar,'duplicate',owned,'xpAwarded',xp_reward,'balance',0) where id=d.id returning * into d;
 response:=to_jsonb(d);
 -- A claimed drop is its own permanent replay guard: return its stored reward on retry.
 -- Keep click receipts only while a drop is playing or ready.
 if d.status='claimed' then
  delete from public.level_drop_requests r where r.profile_id=target and r.response->>'id'=d.id::text;
 else
  insert into public.level_drop_requests(profile_id,request_id,response) values(target,p_request_id,response);
 end if;
 return response;
end $function$
;
drop function public.receive_all_level_drops();
drop function public.receive_level_drop(uuid);
drop function public.ensure_level_drop_mail(uuid);
drop function public.level_drop_upgrade_chance(integer);
drop table public.level_drop_mail_progress;
alter table public.level_drops add constraint legendary_boxes_only check(drop_kind='legendary');
notify pgrst,'reload schema';
commit;
