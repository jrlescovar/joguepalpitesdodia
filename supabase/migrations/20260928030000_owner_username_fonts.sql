begin;
alter table public.public_profiles add column username_font text not null default 'normal'
 check(username_font in ('normal','monocraft','dancingscript','bebasneue','oswald','amaticsc','kalam','patrickhand','lobster') and (username_font='normal' or player_id=1000001));
create function public.username_font_for(p_username text) returns text language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce((select username_font from public.public_profiles where username=p_username and player_id=1000001),'normal');
$$;
create function public.set_username_font(p_font text) returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id();
begin
 if not exists(select 1 from public.public_profiles where id=target and player_id=1000001) then raise exception 'Fonte indisponível para esta conta.'; end if;
 if p_font is null or p_font not in ('normal','monocraft','dancingscript','bebasneue','oswald','amaticsc','kalam','patrickhand','lobster') then raise exception 'Fonte inválida.'; end if;
 update public.public_profiles set username_font=p_font where id=target;
 return public.profile_json(target);
end;
$$;
revoke all on function public.set_username_font(text) from public,anon;
grant execute on function public.set_username_font(text) to authenticated;
revoke all on function public.username_font_for(text) from public,anon;
grant execute on function public.username_font_for(text) to authenticated;
CREATE OR REPLACE FUNCTION public.get_public_profile(p_profile_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  select jsonb_build_object(
    'uid',id,'playerId',player_id,'username',username,'usernameFont',public.username_font_for(username),
    'avatarColor',avatar_color,'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,
    'green',green,'red',red,'level',level,'xp',xp,'rankPoints',rank_points,
    'betaTester',timezone('America/Sao_Paulo',created_at)::date <= date '2026-10-20',
    'supporterActive',public.pass_active(id),
    'passBorderStyle',case when public.box_style_allowed(id,'frame',pass_border_style) then pass_border_style else 'none' end,
    'passNameStyle',case when public.box_style_allowed(id,'name',pass_name_style) then pass_name_style else 'none' end,
    'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,
    'dailyStreakCurrent',daily_streak_current,
    'lastPlayedPrediction',last_played_prediction,'rankPosition',rank_position,'rankChange',rank_change
  ) from public.public_profiles where id=p_profile_id;
$function$
;
CREATE OR REPLACE FUNCTION public.get_ranking_top10()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object('uid',id,'playerId',player_id,'username',username,'usernameFont',public.username_font_for(username),'avatarColor',avatar_color,'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,'passBorderStyle',case when public.box_style_allowed(id,'frame',pass_border_style) then pass_border_style else 'none' end,
    'passNameStyle',case when public.box_style_allowed(id,'name',pass_name_style) then pass_name_style else 'none' end,
    'green',green,'red',red,'level',level,'xp',xp,'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,'dailyStreakCurrent',daily_streak_current,'lastPlayedPrediction',last_played_prediction,'rankPosition',calculated_position,'rankChange',rank_change) order by calculated_position),'[]'::jsonb)
  from (
    select p.*,row_number() over(order by green desc,public.total_xp(level,xp) desc,player_id asc)::integer as calculated_position
    from public.public_profiles p
    order by green desc,public.total_xp(level,xp) desc,player_id asc limit 10
  ) ranked;
$function$
;
CREATE OR REPLACE FUNCTION public.get_global_rank_top10()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object(
    'uid',id,'playerId',player_id,'username',username,'usernameFont',public.username_font_for(username),'avatarColor',avatar_color,
    'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,
    'rankPoints',rank_points,'position',position,
    'passBorderStyle',case when public.box_style_allowed(id,'frame',pass_border_style) then pass_border_style else 'none' end,
    'passNameStyle',case when public.box_style_allowed(id,'name',pass_name_style) then pass_name_style else 'none' end,
    'green',green,'red',red,'level',level,'xp',xp,
    'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,
    'dailyStreakCurrent',daily_streak_current,
    'lastPlayedPrediction',last_played_prediction
  ) order by position),'[]'::jsonb)
  from (
    select p.*,row_number() over(order by rank_points desc,player_id asc)::integer as position
    from public.public_profiles p order by rank_points desc,player_id asc limit 10
  ) ranked;
$function$
;
CREATE OR REPLACE FUNCTION public.get_my_global_rank()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  select jsonb_build_object(
    'uid',p.id,'playerId',p.player_id,'username',p.username,'usernameFont',public.username_font_for(p.username),
    'avatarColor',p.avatar_color,'avatarUrl',p.avatar_url,
    'useGoogleAvatar',p.use_google_avatar,'rankPoints',p.rank_points,
    'position',1 + (
      select count(*) from public.public_profiles other
      where other.rank_points > p.rank_points
        or (other.rank_points = p.rank_points and other.player_id < p.player_id)
    ),
    'green',p.green,'red',p.red,'level',p.level,'xp',p.xp,
    'greenStreakCurrent',p.green_streak_current,'greenStreakMax',p.green_streak_max,
    'dailyStreakCurrent',p.daily_streak_current,
    'lastPlayedPrediction',p.last_played_prediction
  )
  from public.public_profiles p where p.id = public.own_profile_id();
$function$
;
CREATE OR REPLACE FUNCTION public.profile_json(target uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  select jsonb_build_object(
    'uid',p.id,'playerId',p.player_id,'email',v.email,'username',p.username,'usernameFont',public.username_font_for(p.username),
    'usernameLower',lower(p.username),'usernameChangedAt',v.username_changed_at,
    'avatarColor',p.avatar_color,'avatarUrl',p.avatar_url,'useGoogleAvatar',p.use_google_avatar,
    'passBorderStyle',case when public.box_style_allowed(p.id,'frame',p.pass_border_style) then p.pass_border_style else 'none' end,
    'passNameStyle',case when public.box_style_allowed(p.id,'name',p.pass_name_style) then p.pass_name_style else 'none' end,
    'betaTester',timezone('America/Sao_Paulo',p.created_at)::date <= date '2026-10-20',
    'level',p.level,'xp',p.xp,'rankPoints',p.rank_points,'green',p.green,'red',p.red,
    'greenStreakCurrent',p.green_streak_current,'greenStreakMax',p.green_streak_max,
    'dailyStreakCurrent',p.daily_streak_current,
    'lastPlayedDate',p.last_played_prediction,'lastPlayedPrediction',p.last_played_prediction,
    'balance',v.balance,'rankPosition',p.rank_position,'rankChange',p.rank_change)
  from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.id=target;
$function$
;
CREATE OR REPLACE FUNCTION public.get_my_daily_battle()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare target uuid; today date; shown_day date; battle public.daily_battles; opponent public.public_profiles; mine public.public_profiles; shown boolean; my_points integer; their_points integer; my_greens integer; their_greens integer; choices jsonb;
begin
  target := public.own_profile_id();
  if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
  today := public.battle_today();
  shown_day := greatest(today,date '2026-09-26');
  perform public.ensure_daily_battle_round(shown_day);
  if shown_day=today then perform public.finalize_daily_battle(today-1); end if;
  select * into mine from public.public_profiles where id=target;
  select * into battle from public.daily_battles where day_id=shown_day and (player_left=target or player_right=target) limit 1;
  if not found then
    return jsonb_build_object('dayId',shown_day,'preview',shown_day>today,'protected',mine.battle_protected,'offStreak',mine.battle_off_streak,'wins',mine.battle_wins,'losses',mine.battle_losses,'draws',mine.battle_draws);
  end if;
  if battle.player_right is not null then
    select * into opponent from public.public_profiles where id=case when battle.player_left=target then battle.player_right else battle.player_left end;
  end if;
  shown := shown_day<=today and exists (select 1 from public.predictions where day_id=shown_day and status='settled');
  select coalesce(sum(case when k.status='green' then coalesce((select (o->>'rankPoints')::integer from jsonb_array_elements(g.options) o where o->>'id'=k.option_id),0) else 0 end),0),count(*) filter (where k.status='green')
    into my_points,my_greens from public.picks k join public.predictions g on g.day_id=k.prediction_day and g.slot=k.slot
    where k.profile_id=target and k.prediction_day=shown_day;
  if opponent.id is not null then
    select coalesce(sum(case when k.status='green' then coalesce((select (o->>'rankPoints')::integer from jsonb_array_elements(g.options) o where o->>'id'=k.option_id),0) else 0 end),0),count(*) filter (where k.status='green')
      into their_points,their_greens from public.picks k join public.predictions g on g.day_id=k.prediction_day and g.slot=k.slot
      where k.profile_id=opponent.id and k.prediction_day=shown_day;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('uid',id,'username',username,'usernameFont',public.username_font_for(username),'avatarColor',avatar_color,'avatarUrl',avatar_url) order by random()),'[]'::jsonb)
    into choices from (select id,username,avatar_color,avatar_url from public.public_profiles where id<>target and id<>coalesce(opponent.id,target) order by random() limit 4) x;
  return jsonb_build_object(
    'dayId',shown_day,'preview',shown_day>today,'protected',mine.battle_protected,'offStreak',mine.battle_off_streak,
    'wins',mine.battle_wins,'losses',mine.battle_losses,'draws',mine.battle_draws,
    'result',battle.result,'myResult',case when battle.result='draw' then 'draw' when battle.result='no_contest' then 'no_contest' when battle.result='open' then 'open' when (battle.result='left' and battle.player_left=target) or (battle.result='right' and battle.player_right=target) then 'win' else 'loss' end,
    'hasOpponent',opponent.id is not null,'scoreVisible',shown,
    'myPoints',case when shown then my_points else null end,'theirPoints',case when shown then their_points else null end,
    'myGreens',my_greens,'theirGreens',their_greens,
    'me',jsonb_build_object('uid',mine.id,'username',mine.username,'usernameFont',public.username_font_for(mine.username),'avatarColor',mine.avatar_color,'avatarUrl',mine.avatar_url,'passBorderStyle',case when public.box_style_allowed(mine.id,'frame',mine.pass_border_style) then mine.pass_border_style else 'none' end,'passNameStyle',case when public.box_style_allowed(mine.id,'name',mine.pass_name_style) then mine.pass_name_style else 'none' end),
    'opponent',case when opponent.id is null then null else jsonb_build_object('uid',opponent.id,'username',opponent.username,'usernameFont',public.username_font_for(opponent.username),'avatarColor',opponent.avatar_color,'avatarUrl',opponent.avatar_url,'passBorderStyle',case when public.box_style_allowed(opponent.id,'frame',opponent.pass_border_style) then opponent.pass_border_style else 'none' end,'passNameStyle',case when public.box_style_allowed(opponent.id,'name',opponent.pass_name_style) then opponent.pass_name_style else 'none' end) end,
    'reelCandidates',choices
  );
end;
$function$
;
CREATE OR REPLACE FUNCTION public.get_my_previous_daily_battle()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare
  target uuid := public.own_profile_id();
  previous_day date := public.battle_today() - 1;
  battle public.daily_battles;
  mine public.public_profiles;
  opponent public.public_profiles;
  mine_left boolean;
  finished boolean;
begin
  if target is null then raise exception 'Crie seu perfil primeiro.'; end if;

  select * into battle from public.daily_battles
  where day_id = previous_day and (player_left = target or player_right = target)
  limit 1;
  if not found then return null; end if;

  select * into mine from public.public_profiles where id = target;
  mine_left := battle.player_left = target;
  if battle.player_right is not null then
    select * into opponent from public.public_profiles
    where id = case when mine_left then battle.player_right else battle.player_left end;
  end if;
  finished := battle.result <> 'open';

  return jsonb_build_object(
    'dayId', previous_day, 'historical', true, 'preview', false,
    'protected', false, 'result', battle.result,
    'myResult', case when battle.result in ('open', 'draw', 'no_contest') then battle.result
      when (battle.result = 'left' and mine_left) or (battle.result = 'right' and not mine_left) then 'win'
      else 'loss' end,
    'myRankDelta', case when finished then
      case when mine_left then battle.left_rank_delta else battle.right_rank_delta end else null end,
    'hasOpponent', opponent.id is not null,
    'scoreVisible', finished and opponent.id is not null,
    'myPoints', case when finished then case when mine_left then battle.left_points else battle.right_points end else null end,
    'theirPoints', case when finished then case when mine_left then battle.right_points else battle.left_points end else null end,
    'me', jsonb_build_object(
      'uid', mine.id, 'username', mine.username,'usernameFont',public.username_font_for(mine.username), 'avatarColor', mine.avatar_color,
      'avatarUrl', mine.avatar_url,
      'passBorderStyle', case when public.box_style_allowed(mine.id, 'frame', mine.pass_border_style) then mine.pass_border_style else 'none' end,
      'passNameStyle', case when public.box_style_allowed(mine.id, 'name', mine.pass_name_style) then mine.pass_name_style else 'none' end
    ) || public.battle_rank_meta(mine.id),
    'opponent', case when opponent.id is null then null else jsonb_build_object(
      'uid', opponent.id, 'username', opponent.username,'usernameFont',public.username_font_for(opponent.username), 'avatarColor', opponent.avatar_color,
      'avatarUrl', opponent.avatar_url,
      'passBorderStyle', case when public.box_style_allowed(opponent.id, 'frame', opponent.pass_border_style) then opponent.pass_border_style else 'none' end,
      'passNameStyle', case when public.box_style_allowed(opponent.id, 'name', opponent.pass_name_style) then opponent.pass_name_style else 'none' end
    ) || public.battle_rank_meta(opponent.id) end,
    'reelCandidates', '[]'::jsonb
  );
end;
$function$
;
notify pgrst, 'reload schema';
commit;
