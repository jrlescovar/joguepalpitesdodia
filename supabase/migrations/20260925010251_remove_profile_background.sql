begin;

create or replace function public.profile_json(target uuid)
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'uid',p.id,'playerId',p.player_id,'email',v.email,'username',p.username,
    'usernameLower',lower(p.username),'usernameChangedAt',v.username_changed_at,
    'avatarColor',p.avatar_color,'avatarUrl',p.avatar_url,'useGoogleAvatar',p.use_google_avatar,
    'passBorderStyle',case when public.pass_active(p.id) then p.pass_border_style else 'none' end,
    'passNameStyle',case when public.pass_active(p.id) then p.pass_name_style else 'none' end,
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
    'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,
    'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,
    'lastPlayedPrediction',last_played_prediction,'rankPosition',rank_position,'rankChange',rank_change
  ) from public.public_profiles where id=p_profile_id;
$$;

drop function if exists public.set_profile_background(text);
alter table public.public_profiles drop constraint if exists profile_background_style_check;
alter table public.public_profiles drop column if exists profile_background_style;

commit;
