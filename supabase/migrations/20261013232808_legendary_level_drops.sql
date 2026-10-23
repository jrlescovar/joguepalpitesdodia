begin;
alter table public.level_drops add column drop_kind text not null default 'normal' check(drop_kind in ('normal','legendary'));
alter table public.level_drops add constraint legendary_drop_state check(drop_kind<>'legendary' or (milestone=0 and tier=4 and clicks_left=0 and status in ('ready','claimed')));
alter table public.player_mail drop constraint player_mail_kind_check;
alter table public.player_mail add constraint player_mail_kind_check check(kind in ('drop','legendary_drop','classic','font','halloween','premium','frame'));
CREATE OR REPLACE FUNCTION public.receive_mail(p_kind text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare target uuid:=public.own_profile_id(); quantity integer; sender uuid; balance_table text;
begin
 if p_kind is null or (p_kind not in ('drop','legendary_drop','classic','font','halloween','premium') and p_kind not like 'frame:%') then raise exception 'Entrega inválida.'; end if;
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
 if p_kind='legendary_drop' then
  insert into public.level_drops(profile_id,milestone,received_at,drop_kind,tier,clicks_left,status) select target,0,now(),'legendary',4,0,'ready' from generate_series(1,quantity);
 elsif p_kind='drop' then
  insert into public.level_drops(profile_id,milestone,received_at) select target,0,now() from generate_series(1,quantity);
 elsif p_kind in ('classic','font','halloween') then
  balance_table:=case p_kind when 'classic' then 'box_balances' when 'font' then 'font_box_balances' else 'halloween_box_balances' end;
  if quantity>0 then execute format('insert into public.%I(profile_id,balance) values($1,$2) on conflict(profile_id) do update set balance=public.%I.balance+excluded.balance',balance_table,balance_table) using target,quantity; end if;
 elsif p_kind='premium' then
  if quantity>0 then insert into public.pass_grants(profile_id,grant_ends_at,granted_by) values(target,now()+make_interval(days=>quantity),sender)
  on conflict(profile_id) do update set grant_ends_at=greatest(now(),public.pass_grants.grant_ends_at)+make_interval(days=>quantity),revoked_at=null,granted_by=excluded.granted_by,updated_at=now(); end if;
 end if;
end $function$;

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
 if d.received_at is null then raise exception 'Receba o drop no correio antes de abrir.'; end if;
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

create function public.admin_grant_legendary_drops(p_profile_id uuid,p_quantity integer) returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
 if not public.is_admin() then raise exception 'Somente admin pode enviar recompensas.'; end if;
 if p_quantity is null or p_quantity<1 or p_quantity>100 then raise exception 'Informe de 1 a 100.'; end if;
 insert into public.player_mail(profile_id,kind,quantity,granted_by) values(p_profile_id,'legendary_drop',p_quantity,auth.uid());
end $$;
revoke all on function public.admin_grant_legendary_drops(uuid,integer) from public,anon;
grant execute on function public.admin_grant_legendary_drops(uuid,integer) to authenticated;
commit;

