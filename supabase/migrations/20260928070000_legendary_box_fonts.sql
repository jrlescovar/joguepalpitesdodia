begin;
alter table public.box_style_catalog add column item_kind text check(item_kind is null or item_kind='font');
insert into public.box_style_catalog(style,rarity,item_kind) values
 ('monocraft','legendary','font'),('dancingscript','legendary','font'),('bebasneue','legendary','font'),('amaticsc','legendary','font'),('kalam','legendary','font');
alter table public.box_inventory drop constraint box_inventory_kind_check;
alter table public.box_inventory add constraint box_inventory_kind_check check(kind in ('name','frame','font'));
alter table public.box_openings drop constraint box_openings_kind_check;
alter table public.box_openings add constraint box_openings_kind_check check(kind in ('name','frame','font'));
alter table public.public_profiles drop constraint public_profiles_check;
create or replace function public.username_font_allowed(p_profile_id uuid,p_font text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select p_font='normal' or (exists(select 1 from public.box_style_catalog c where c.style=p_font and c.item_kind='font') and
 (exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001) or exists(select 1 from public.box_inventory i where i.profile_id=p_profile_id and i.kind='font' and i.style=p_font)));
$$;
revoke all on function public.username_font_allowed(uuid,text) from public,anon,authenticated;
create or replace function public.set_username_font(p_font text) returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id();
begin
 if target is null then raise exception 'Crie seu perfil primeiro.';end if;
 if not public.username_font_allowed(target,p_font) then raise exception 'Fonte indisponível para esta conta.';end if;
 update public.public_profiles set username_font=p_font where id=target;
 return public.profile_json(target);
end;$$;
create or replace function public.username_font_for(p_username text) returns text language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce((select case when public.username_font_allowed(p.id,p.username_font) then p.username_font else 'normal' end from public.public_profiles p where p.username=p_username),'normal');
$$;
CREATE OR REPLACE FUNCTION public.open_box(p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare target uuid; available integer; prior jsonb; roll integer; selected_rarity text; selected_kind text;
  style_count integer; selected_style text; already_owned boolean; reward integer := 0; progress integer[]; opening_id uuid;
  player record;
begin
  target := public.own_profile_id();
  if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
  if p_request_id is null then raise exception 'Identificador da abertura obrigatório.'; end if;
  insert into public.box_balances(profile_id,balance) values(target,0) on conflict(profile_id) do nothing;
  select balance into available from public.box_balances where profile_id=target for update;
  select jsonb_build_object('id',o.id,'kind',o.kind,'style',o.style,'rarity',o.rarity,'duplicate',o.duplicate,'xpAwarded',o.xp_awarded,'balance',available)
    into prior from public.box_openings o where o.profile_id=target and o.request_id=p_request_id;
  if prior is not null then return prior; end if;
  if available < 1 then raise exception 'Você não tem caixas para abrir.'; end if;
  roll := public.box_random_index(100);
  selected_rarity := case when roll < 40 then 'common' when roll < 70 then 'rare' when roll < 85 then 'epic' when roll < 95 then 'mythic' else 'legendary' end;
  select count(*) into style_count from (select c.style,k.kind from public.box_style_catalog c cross join (values ('name'),('frame'),('font')) k(kind) where c.rarity=selected_rarity and ((c.item_kind is null and k.kind in ('name','frame')) or c.item_kind=k.kind)) items;
  select items.style,items.kind into selected_style,selected_kind from (select c.style,k.kind from public.box_style_catalog c cross join (values ('name'),('frame'),('font')) k(kind) where c.rarity=selected_rarity and ((c.item_kind is null and k.kind in ('name','frame')) or c.item_kind=k.kind)) items order by items.style,items.kind offset public.box_random_index(style_count) limit 1;
  already_owned := exists(select 1 from public.public_profiles p where p.id=target and p.player_id=1000001)
    or exists(select 1 from public.box_inventory i where i.profile_id=target and i.kind=selected_kind and i.style=selected_style);
  if already_owned then
    reward := case selected_rarity when 'common' then 25 when 'rare' then 50 when 'epic' then 100 when 'mythic' then 250 else 500 end;
    select p.level,p.xp into player from public.public_profiles p where p.id=target for update;
    progress := public.award_xp(player.level,player.xp,reward);
    update public.public_profiles set level=progress[1],xp=progress[2],updated_at=now() where id=target;
  else
    insert into public.box_inventory(profile_id,kind,style) values(target,selected_kind,selected_style);
  end if;
  update public.box_balances set balance=balance-1 where profile_id=target returning balance into available;
  insert into public.box_openings(profile_id,request_id,kind,style,rarity,duplicate,xp_awarded)
    values(target,p_request_id,selected_kind,selected_style,selected_rarity,already_owned,reward) returning id into opening_id;
  return jsonb_build_object('id',opening_id,'kind',selected_kind,'style',selected_style,'rarity',selected_rarity,'duplicate',already_owned,'xpAwarded',reward,'balance',available);
end;
$function$;

insert into public.box_inventory(profile_id,kind,style)
 select p.id,'font',c.style from public.public_profiles p cross join public.box_style_catalog c where p.player_id=1000002 and c.item_kind='font' on conflict do nothing;
commit;
