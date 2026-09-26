begin;

-- Previous selections outside the newly available tier are no longer displayed.
update public.public_profiles
set pass_name_style = case when pass_name_style in ('none','blood','purple','green','dark-blue','orange','pink') then pass_name_style else 'none' end,
    pass_border_style = case when pass_border_style in ('none','blood','purple','green','dark-blue','orange','pink') then pass_border_style else 'none' end,
    updated_at = now()
where player_id <> 1000001
  and (pass_name_style not in ('none','blood','purple','green','dark-blue','orange','pink') or pass_border_style not in ('none','blood','purple','green','dark-blue','orange','pink'));

create or replace function public.pass_style_visible(p_profile_id uuid)
returns boolean language sql stable security definer set search_path = public, auth, pg_temp as $$
  select exists (
    select 1 from public.public_profiles p
    where p.id = p_profile_id and (p.player_id = 1000001 or public.pass_active(p.id))
  );
$$;
revoke execute on function public.pass_style_visible(uuid) from public, anon, authenticated;


create or replace function public.set_pass_styles(p_border_style text,p_name_style text)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid; owner_profile boolean;
begin
  target := public.own_profile_id();
  if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
  select p.player_id = 1000001 into owner_profile from public.public_profiles p where p.id = target;
  if not owner_profile and not public.pass_active(target) then raise exception 'O Plus precisa estar ativo para personalizar o perfil.'; end if;
  if p_border_style is null or p_border_style not in ('none','gold','blood','purple','green','dark-blue','orange','pink','sunset','ember','rose-purple','midnight-electric','green-gold','lilac-silver','wine-rose','ice-blue','navy-pink','graphite-silver','rainbow','royal-sapphire','sunset-ocean','neon-circuit','coral-lilac','legend-nebula','legend-abyss','legend-prism','legend-solar','myth-petroleum-bronze','myth-burgundy-sand','myth-cerulean-rust','myth-plum-copper','myth-jade-mauve','myth-olive-rose-graphite','myth-fuchsia-petroleum','rare-plum-beige','legend-ruby-eclipse')
    or p_name_style is null or p_name_style not in ('none','gold','blood','purple','green','dark-blue','orange','pink','sunset','ember','rose-purple','midnight-electric','green-gold','lilac-silver','wine-rose','ice-blue','navy-pink','graphite-silver','rainbow','royal-sapphire','sunset-ocean','neon-circuit','coral-lilac','legend-nebula','legend-abyss','legend-prism','legend-solar','myth-petroleum-bronze','myth-burgundy-sand','myth-cerulean-rust','myth-plum-copper','myth-jade-mauve','myth-olive-rose-graphite','myth-fuchsia-petroleum','rare-plum-beige','legend-ruby-eclipse') then
    raise exception 'Escolha um estilo disponível.';
  end if;
  if not owner_profile and (p_border_style not in ('none','blood','purple','green','dark-blue','orange','pink') or p_name_style not in ('none','blood','purple','green','dark-blue','orange','pink')) then
    raise exception 'Este estilo ainda não foi desbloqueado.';
  end if;
  update public.public_profiles set pass_border_style = p_border_style,
    pass_name_style = p_name_style, updated_at = now() where id = target;
  return public.get_pass_status();
end;
$$;

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
    'borderStyle', case when public.pass_style_visible(p.id) then p.pass_border_style else 'none' end,
    'nameStyle', case when public.pass_style_visible(p.id) then p.pass_name_style else 'none' end
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
    'passBorderStyle',case when public.pass_style_visible(p.id) then p.pass_border_style else 'none' end,
    'passNameStyle',case when public.pass_style_visible(p.id) then p.pass_name_style else 'none' end,
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
    'passBorderStyle',case when public.pass_style_visible(id) then pass_border_style else 'none' end,
    'passNameStyle',case when public.pass_style_visible(id) then pass_name_style else 'none' end,
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
    'passBorderStyle',case when public.pass_style_visible(id) then pass_border_style else 'none' end,
    'passNameStyle',case when public.pass_style_visible(id) then pass_name_style else 'none' end,
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
  select coalesce(jsonb_agg(jsonb_build_object('uid',id,'playerId',player_id,'username',username,'avatarColor',avatar_color,'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,'passBorderStyle',case when public.pass_style_visible(id) then pass_border_style else 'none' end,
    'passNameStyle',case when public.pass_style_visible(id) then pass_name_style else 'none' end,
    'green',green,'red',red,'level',level,'xp',xp,'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,'lastPlayedPrediction',last_played_prediction,'rankPosition',calculated_position,'rankChange',rank_change) order by calculated_position),'[]'::jsonb)
  from (
    select p.*,row_number() over(order by green desc,public.total_xp(level,xp) desc,player_id asc)::integer as calculated_position
    from public.public_profiles p
    order by green desc,public.total_xp(level,xp) desc,player_id asc limit 10
  ) ranked;
$$;

notify pgrst, 'reload schema';
commit;
