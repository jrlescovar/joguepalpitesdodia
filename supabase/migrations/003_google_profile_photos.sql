-- Read the Google-hosted photo from Supabase Auth. Players cannot submit it.
create or replace function public.profile_json(target uuid)
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'uid',p.id,'playerId',p.player_id,'email',v.email,'username',p.username,
    'usernameLower',lower(p.username),'usernameChangedAt',v.username_changed_at,
    'avatarColor',p.avatar_color,'avatarUrl',case
      when coalesce(u.raw_app_meta_data->>'provider','')='google'
        and coalesce(u.raw_user_meta_data->>'avatar_url',u.raw_user_meta_data->>'picture','') like 'https://lh3.googleusercontent.com/%'
      then coalesce(u.raw_user_meta_data->>'avatar_url',u.raw_user_meta_data->>'picture') else null end,
    'level',p.level,'xp',p.xp,'green',p.green,'red',p.red,
    'greenStreakCurrent',p.green_streak_current,'greenStreakMax',p.green_streak_max,
    'dailyStreakCurrent',p.daily_streak_current,'dailyStreakMax',p.daily_streak_max,
    'lastPlayedDate',p.last_played_prediction,'lastPlayedPrediction',p.last_played_prediction,
    'balance',v.balance,'rankPosition',p.rank_position,'rankChange',p.rank_change)
  from public.public_profiles p
  join public.private_profiles v on v.profile_id=p.id
  left join auth.users u on u.id=v.auth_user_id
  where p.id=target;
$$;

create or replace function public.get_ranking_top10()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'uid',r.id,'playerId',r.player_id,'username',r.username,'avatarColor',r.avatar_color,
    'avatarUrl',case when coalesce(u.raw_app_meta_data->>'provider','')='google'
      and coalesce(u.raw_user_meta_data->>'avatar_url',u.raw_user_meta_data->>'picture','') like 'https://lh3.googleusercontent.com/%'
      then coalesce(u.raw_user_meta_data->>'avatar_url',u.raw_user_meta_data->>'picture') else null end,
    'green',r.green,'red',r.red,'level',r.level,'xp',r.xp,
    'greenStreakCurrent',r.green_streak_current,'greenStreakMax',r.green_streak_max,
    'dailyStreakCurrent',r.daily_streak_current,'dailyStreakMax',r.daily_streak_max,
    'lastPlayedPrediction',r.last_played_prediction,'rankPosition',r.calculated_position,'rankChange',r.rank_change
  ) order by r.calculated_position),'[]'::jsonb)
  from (select p.*,row_number() over(order by green desc,player_id asc)::integer as calculated_position
    from public.public_profiles p order by green desc,player_id asc limit 10) r
  left join public.private_profiles v on v.profile_id=r.id
  left join auth.users u on u.id=v.auth_user_id;
$$;

create or replace function public.get_public_profile(p_profile_id uuid)
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'uid',p.id,'playerId',p.player_id,'username',p.username,'avatarColor',p.avatar_color,
    'avatarUrl',case when coalesce(u.raw_app_meta_data->>'provider','')='google'
      and coalesce(u.raw_user_meta_data->>'avatar_url',u.raw_user_meta_data->>'picture','') like 'https://lh3.googleusercontent.com/%'
      then coalesce(u.raw_user_meta_data->>'avatar_url',u.raw_user_meta_data->>'picture') else null end,
    'green',p.green,'red',p.red,'level',p.level,'xp',p.xp,
    'greenStreakCurrent',p.green_streak_current,'greenStreakMax',p.green_streak_max,
    'dailyStreakCurrent',p.daily_streak_current,'dailyStreakMax',p.daily_streak_max,
    'lastPlayedPrediction',p.last_played_prediction,'rankPosition',p.rank_position,'rankChange',p.rank_change)
  from public.public_profiles p
  left join public.private_profiles v on v.profile_id=p.id
  left join auth.users u on u.id=v.auth_user_id
  where p.id=p_profile_id;
$$;

notify pgrst, 'reload schema';
