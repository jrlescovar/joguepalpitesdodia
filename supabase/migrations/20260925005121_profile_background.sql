begin;

alter table public.public_profiles
  add column if not exists profile_background_style text not null default 'none';
alter table public.public_profiles
  add constraint profile_background_style_check
  check (profile_background_style in ('none','blue','purple','green','orange','pink'));

create or replace function public.set_profile_background(p_style text)
returns text language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid;
begin
  target := public.own_profile_id();
  if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
  if not public.pass_active(target) then raise exception 'A assinatura precisa estar ativa para personalizar o perfil.'; end if;
  if p_style is null or p_style not in ('none','blue','purple','green','orange','pink') then
    raise exception 'Escolha um fundo disponível.';
  end if;
  update public.public_profiles
    set profile_background_style = p_style, updated_at = now()
    where id = target;
  return p_style;
end;
$$;
revoke execute on function public.set_profile_background(text) from public, anon, authenticated;
grant execute on function public.set_profile_background(text) to authenticated;

create or replace function public.profile_json(target uuid)
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'uid',p.id,'playerId',p.player_id,'email',v.email,'username',p.username,
    'usernameLower',lower(p.username),'usernameChangedAt',v.username_changed_at,
    'avatarColor',p.avatar_color,'avatarUrl',p.avatar_url,'useGoogleAvatar',p.use_google_avatar,
    'passBorderStyle',case when public.pass_active(p.id) then p.pass_border_style else 'none' end,
    'passNameStyle',case when public.pass_active(p.id) then p.pass_name_style else 'none' end,
    'profileBackgroundStyle',case when public.pass_active(p.id) then p.profile_background_style else 'none' end,
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
    'passBorderStyle',case when public.pass_active(id) then pass_border_style else 'none' end,
    'passNameStyle',case when public.pass_active(id) then pass_name_style else 'none' end,
    'profileBackgroundStyle',case when public.pass_active(id) then profile_background_style else 'none' end,
    'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,
    'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,
    'lastPlayedPrediction',last_played_prediction,'rankPosition',rank_position,'rankChange',rank_change
  ) from public.public_profiles where id=p_profile_id;
$$;

commit;
