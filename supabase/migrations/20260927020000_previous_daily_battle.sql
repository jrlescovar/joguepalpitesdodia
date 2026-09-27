begin;

-- A player may revisit their own battle from yesterday while it is retained.
create or replace function public.get_my_previous_daily_battle()
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
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
      'uid', mine.id, 'username', mine.username, 'avatarColor', mine.avatar_color,
      'avatarUrl', mine.avatar_url,
      'passBorderStyle', case when public.box_style_allowed(mine.id, 'frame', mine.pass_border_style) then mine.pass_border_style else 'none' end,
      'passNameStyle', case when public.box_style_allowed(mine.id, 'name', mine.pass_name_style) then mine.pass_name_style else 'none' end
    ) || public.battle_rank_meta(mine.id),
    'opponent', case when opponent.id is null then null else jsonb_build_object(
      'uid', opponent.id, 'username', opponent.username, 'avatarColor', opponent.avatar_color,
      'avatarUrl', opponent.avatar_url,
      'passBorderStyle', case when public.box_style_allowed(opponent.id, 'frame', opponent.pass_border_style) then opponent.pass_border_style else 'none' end,
      'passNameStyle', case when public.box_style_allowed(opponent.id, 'name', opponent.pass_name_style) then opponent.pass_name_style else 'none' end
    ) || public.battle_rank_meta(opponent.id) end,
    'reelCandidates', '[]'::jsonb
  );
end;
$$;

revoke execute on function public.get_my_previous_daily_battle() from public, anon, authenticated;
grant execute on function public.get_my_previous_daily_battle() to authenticated;
notify pgrst, 'reload schema';

commit;
