begin;

create table public.box_style_catalog (
  style text primary key,
  rarity text not null check (rarity in ('common','rare','epic','mythic','legendary'))
);
insert into public.box_style_catalog(style,rarity) values
  ('blood','common'),('purple','common'),('green','common'),('dark-blue','common'),('orange','common'),('pink','common'),
  ('sunset','rare'),('ember','rare'),('rose-purple','rare'),('green-gold','rare'),('lilac-silver','rare'),('ice-blue','rare'),('navy-pink','rare'),('royal-sapphire','rare'),('coral-lilac','rare'),
  ('midnight-electric','epic'),('graphite-silver','epic'),('wine-rose','epic'),('neon-circuit','epic'),('sunset-ocean','epic'),('rare-plum-beige','epic'),
  ('myth-petroleum-bronze','mythic'),('myth-burgundy-sand','mythic'),('myth-cerulean-rust','mythic'),('myth-plum-copper','mythic'),('myth-jade-mauve','mythic'),('myth-olive-rose-graphite','mythic'),('myth-fuchsia-petroleum','mythic'),
  ('gold','legendary'),('rainbow','legendary'),('legend-nebula','legendary'),('legend-abyss','legendary'),('legend-prism','legendary'),('legend-solar','legendary'),('legend-ruby-eclipse','legendary');

create table public.box_balances (
  profile_id uuid primary key references public.public_profiles(id) on delete cascade,
  balance integer not null default 0 check (balance >= 0)
);
create table public.box_inventory (
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  kind text not null check (kind in ('name','frame')),
  style text not null references public.box_style_catalog(style),
  acquired_at timestamptz not null default now(),
  primary key(profile_id,kind,style)
);
create table public.box_openings (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  request_id uuid not null,
  kind text not null check (kind in ('name','frame')),
  style text not null references public.box_style_catalog(style),
  rarity text not null check (rarity in ('common','rare','epic','mythic','legendary')),
  duplicate boolean not null,
  xp_awarded integer not null default 0 check (xp_awarded in (0,25,50,100,250,500)),
  opened_at timestamptz not null default now(),
  unique(profile_id,request_id)
);
create index box_openings_profile_time_idx on public.box_openings(profile_id,opened_at desc);
create table public.box_grants (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  quantity integer not null check (quantity between 1 and 100),
  granted_by uuid not null,
  granted_at timestamptz not null default now()
);

alter table public.box_style_catalog enable row level security;
alter table public.box_balances enable row level security;
alter table public.box_inventory enable row level security;
alter table public.box_openings enable row level security;
alter table public.box_grants enable row level security;
revoke all on public.box_style_catalog,public.box_balances,public.box_inventory,public.box_openings,public.box_grants from public,anon,authenticated;

-- Rejection sampling avoids favoring some rarities or catalog positions.
create or replace function public.box_random_index(p_count integer)
returns integer language plpgsql volatile security definer set search_path=public,auth,pg_temp as $$
declare sample integer; draw_limit integer;
begin
  if p_count is null or p_count < 1 or p_count > 100 then raise exception 'Faixa de sorteio inválida.'; end if;
  draw_limit := (256 / p_count) * p_count;
  loop
    sample := get_byte(decode(substr(replace(gen_random_uuid()::text,'-',''),1,2),'hex'),0);
    exit when sample < draw_limit;
  end loop;
  return sample % p_count;
end;
$$;
revoke execute on function public.box_random_index(integer) from public,anon,authenticated;

create or replace function public.box_style_allowed(p_profile_id uuid,p_kind text,p_style text)
returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
  select p_style = 'none'
    or exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001)
    or (p_style in ('blood','purple','green','dark-blue','orange','pink') and public.pass_active(p_profile_id))
    or exists(select 1 from public.box_inventory i where i.profile_id=p_profile_id and i.kind=p_kind and i.style=p_style);
$$;
revoke execute on function public.box_style_allowed(uuid,text,text) from public,anon,authenticated;

create or replace function public.get_box_state()
returns jsonb language sql stable security definer set search_path=public,auth,pg_temp as $$
  select jsonb_build_object(
    'balance',coalesce((select b.balance from public.box_balances b where b.profile_id=public.own_profile_id()),0),
    'inventory',coalesce((select jsonb_agg(jsonb_build_object('kind',i.kind,'style',i.style,'rarity',c.rarity) order by i.acquired_at)
      from public.box_inventory i join public.box_style_catalog c on c.style=i.style where i.profile_id=public.own_profile_id()),'[]'::jsonb)
  );
$$;
revoke execute on function public.get_box_state() from public,anon,authenticated;
grant execute on function public.get_box_state() to authenticated;

create or replace function public.admin_get_box_balance(p_profile_id uuid)
returns integer language plpgsql stable security definer set search_path=public,auth,pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode consultar caixas.'; end if;
  if not exists(select 1 from public.public_profiles where id=p_profile_id) then raise exception 'Jogador não encontrado.'; end if;
  return coalesce((select balance from public.box_balances where profile_id=p_profile_id),0);
end;
$$;
revoke execute on function public.admin_get_box_balance(uuid) from public,anon,authenticated;
grant execute on function public.admin_get_box_balance(uuid) to authenticated;

create or replace function public.admin_grant_boxes(p_profile_id uuid,p_quantity integer)
returns integer language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare new_balance integer;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode conceder caixas.'; end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 100 then raise exception 'Informe de 1 a 100 caixas.'; end if;
  if not exists(select 1 from public.public_profiles where id=p_profile_id) then raise exception 'Jogador não encontrado.'; end if;
  insert into public.box_balances(profile_id,balance) values(p_profile_id,p_quantity)
    on conflict(profile_id) do update set balance=box_balances.balance+excluded.balance
    returning balance into new_balance;
  insert into public.box_grants(profile_id,quantity,granted_by) values(p_profile_id,p_quantity,auth.uid());
  return new_balance;
end;
$$;
revoke execute on function public.admin_grant_boxes(uuid,integer) from public,anon,authenticated;
grant execute on function public.admin_grant_boxes(uuid,integer) to authenticated;

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
  already_owned := exists(select 1 from public.box_inventory i where i.profile_id=target and i.kind=selected_kind and i.style=selected_style);
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
revoke execute on function public.open_box(uuid) from public,anon,authenticated;
grant execute on function public.open_box(uuid) to authenticated;

create or replace function public.set_pass_styles(p_border_style text,p_name_style text)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid;
begin
  target := public.own_profile_id();
  if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
  if p_border_style is null or p_name_style is null
    or not public.box_style_allowed(target,'frame',p_border_style)
    or not public.box_style_allowed(target,'name',p_name_style) then
    raise exception 'Este estilo ainda não foi desbloqueado.';
  end if;
  update public.public_profiles set pass_border_style=p_border_style,pass_name_style=p_name_style,updated_at=now() where id=target;
  return public.get_pass_status();
end;
$$;
revoke execute on function public.set_pass_styles(text,text) from public,anon,authenticated;
grant execute on function public.set_pass_styles(text,text) to authenticated;

-- Profile and ranking response functions below check each equipped slot separately.
create or replace function public.get_pass_status()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'active', public.pass_active(p.id),
    'status', coalesce(s.status, 'none'),
    'periodEndsAt', s.current_period_ends_at,
    'cancelAtPeriodEnd', coalesce(s.cancel_at_period_end, false),
    'freeActive', coalesce(g.revoked_at is null and g.grant_ends_at > now(), false),
    'freeEndsAt', case when g.revoked_at is null and g.grant_ends_at > now() then g.grant_ends_at else null end,
    'prepaidActive', coalesce(x.ends_at > now(), false),
    'prepaidEndsAt', case when x.ends_at > now() then x.ends_at else null end,
    'borderStyle', case when public.box_style_allowed(p.id,'frame',p.pass_border_style) then p.pass_border_style else 'none' end,
    'nameStyle', case when public.box_style_allowed(p.id,'name',p.pass_name_style) then p.pass_name_style else 'none' end
  ) from public.public_profiles p
  left join public.pass_subscriptions s on s.profile_id = p.id
  left join public.pass_grants g on g.profile_id = p.id
  left join public.pass_prepaid x on x.profile_id = p.id
  where p.id = public.own_profile_id();
$$;

create or replace function public.profile_json(target uuid)
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'uid',p.id,'playerId',p.player_id,'email',v.email,'username',p.username,
    'usernameLower',lower(p.username),'usernameChangedAt',v.username_changed_at,
    'avatarColor',p.avatar_color,'avatarUrl',p.avatar_url,'useGoogleAvatar',p.use_google_avatar,
    'passBorderStyle',case when public.box_style_allowed(p.id,'frame',p.pass_border_style) then p.pass_border_style else 'none' end,
    'passNameStyle',case when public.box_style_allowed(p.id,'name',p.pass_name_style) then p.pass_name_style else 'none' end,
    'betaTester',timezone('America/Sao_Paulo',p.created_at)::date <= date '2026-10-20',
    'level',p.level,'xp',p.xp,'rankPoints',p.rank_points,'green',p.green,'red',p.red,
    'greenStreakCurrent',p.green_streak_current,'greenStreakMax',p.green_streak_max,
    'dailyStreakCurrent',p.daily_streak_current,'dailyStreakMax',p.daily_streak_max,
    'lastPlayedDate',p.last_played_prediction,'lastPlayedPrediction',p.last_played_prediction,
    'balance',v.balance,'rankPosition',p.rank_position,'rankChange',p.rank_change)
  from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.id=target;
$$;

create or replace function public.get_public_profile(p_profile_id uuid)
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'uid',id,'playerId',player_id,'username',username,
    'avatarColor',avatar_color,'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,
    'green',green,'red',red,'level',level,'xp',xp,'rankPoints',rank_points,
    'betaTester',timezone('America/Sao_Paulo',created_at)::date <= date '2026-10-20',
    'supporterActive',public.pass_active(id),
    'passBorderStyle',case when public.box_style_allowed(id,'frame',pass_border_style) then pass_border_style else 'none' end,
    'passNameStyle',case when public.box_style_allowed(id,'name',pass_name_style) then pass_name_style else 'none' end,
    'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,
    'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,
    'lastPlayedPrediction',last_played_prediction,'rankPosition',rank_position,'rankChange',rank_change
  ) from public.public_profiles where id=p_profile_id;
$$;

create or replace function public.get_global_rank_top10()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'uid',id,'playerId',player_id,'username',username,'avatarColor',avatar_color,
    'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,
    'rankPoints',rank_points,'position',position,
    'passBorderStyle',case when public.box_style_allowed(id,'frame',pass_border_style) then pass_border_style else 'none' end,
    'passNameStyle',case when public.box_style_allowed(id,'name',pass_name_style) then pass_name_style else 'none' end,
    'green',green,'red',red,'level',level,'xp',xp,
    'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,
    'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,
    'lastPlayedPrediction',last_played_prediction
  ) order by position),'[]'::jsonb)
  from (
    select p.*,row_number() over(order by rank_points desc,player_id asc)::integer as position
    from public.public_profiles p order by rank_points desc,player_id asc limit 10
  ) ranked;
$$;

create or replace function public.get_ranking_top10()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('uid',id,'playerId',player_id,'username',username,'avatarColor',avatar_color,'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,'passBorderStyle',case when public.box_style_allowed(id,'frame',pass_border_style) then pass_border_style else 'none' end,
    'passNameStyle',case when public.box_style_allowed(id,'name',pass_name_style) then pass_name_style else 'none' end,
    'green',green,'red',red,'level',level,'xp',xp,'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,'lastPlayedPrediction',last_played_prediction,'rankPosition',calculated_position,'rankChange',rank_change) order by calculated_position),'[]'::jsonb)
  from (
    select p.*,row_number() over(order by green desc,public.total_xp(level,xp) desc,player_id asc)::integer as calculated_position
    from public.public_profiles p
    order by green desc,public.total_xp(level,xp) desc,player_id asc limit 10
  ) ranked;
$$;

notify pgrst, 'reload schema';
commit;
