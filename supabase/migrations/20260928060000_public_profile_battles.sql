begin;
CREATE OR REPLACE FUNCTION public.profile_daily_battle(p_profile_id uuid, p_day_id date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare
  target uuid := p_profile_id;
  previous_day date := p_day_id;
  battle public.daily_battles;
  mine public.public_profiles;
  opponent public.public_profiles;
  mine_left boolean;
  finished boolean;
begin
  if target is null then return null; end if;

  select * into battle from public.daily_battles
  where day_id = previous_day and (player_left = target or player_right = target)
  limit 1;
  if not found or battle.player_right is null then return null; end if;

  select * into mine from public.public_profiles where id = target;
  mine_left := battle.player_left = target;
  if battle.player_right is not null then
    select * into opponent from public.public_profiles
    where id = case when mine_left then battle.player_right else battle.player_left end;
  end if;
  finished := battle.result <> 'open';

  return jsonb_build_object(
    'dayId', previous_day, 'historical', previous_day < public.battle_today(), 'preview', false,
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
revoke all on function public.profile_daily_battle(uuid,date) from public,anon,authenticated;
create function public.get_profile_daily_battles(p_profile_id uuid) returns jsonb language sql volatile security definer set search_path=public,auth,pg_temp as $$
 select jsonb_build_object('today',public.profile_daily_battle(p_profile_id,public.battle_today()),'previous',public.profile_daily_battle(p_profile_id,public.battle_today()-1));
$$;
revoke all on function public.get_profile_daily_battles(uuid) from public,anon;
grant execute on function public.get_profile_daily_battles(uuid) to authenticated;
notify pgrst, 'reload schema';
commit;

