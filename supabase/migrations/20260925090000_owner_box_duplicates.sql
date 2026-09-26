begin;

-- Player #1000001 already owns every name and frame style, even without an
-- explicit box_inventory row for each combination.
create or replace function public.open_box(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
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
  selected_kind := case when public.box_random_index(2)=0 then 'name' else 'frame' end;
  select count(*) into style_count from public.box_style_catalog c where c.rarity=selected_rarity;
  select c.style into selected_style from public.box_style_catalog c where c.rarity=selected_rarity order by c.style offset public.box_random_index(style_count) limit 1;
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
$$;

-- Correct previously opened owner boxes once. The predicate makes the XP
-- compensation idempotent if this migration is ever applied again.
do $$
declare owner_id uuid; reward_total integer; player_level integer; player_xp integer; progress integer[];
begin
  select p.id,p.level,p.xp into owner_id,player_level,player_xp
    from public.public_profiles p where p.player_id=1000001 for update;
  if owner_id is not null then
    with corrected as (
      update public.box_openings o
      set duplicate=true,
          xp_awarded=case o.rarity when 'common' then 25 when 'rare' then 50 when 'epic' then 100 when 'mythic' then 250 else 500 end
      where o.profile_id=owner_id and not o.duplicate
      returning o.xp_awarded
    ) select coalesce(sum(xp_awarded),0)::integer into reward_total from corrected;
    if reward_total > 0 then
      progress := public.award_xp(player_level,player_xp,reward_total);
      update public.public_profiles set level=progress[1],xp=progress[2],updated_at=now() where id=owner_id;
    end if;
  end if;
end;
$$;

notify pgrst, 'reload schema';
commit;
