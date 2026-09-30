begin;
do $$
declare battle public.daily_battles; left_before integer; right_before integer;
  left_after integer; right_after integer;
begin
  select * into battle from public.daily_battles
    where day_id=public.battle_today() and player_right is not null and result='open'
    order by id limit 1;
  if battle.id is null then raise exception 'No open paired battle for draw test'; end if;
  if public.battle_winner(battle.player_left,battle.player_right,108,108,9,1)<>'draw'
    or public.battle_winner(battle.player_left,battle.player_right,108,108,1,9)<>'draw'
    or public.battle_winner(battle.player_left,battle.player_right,109,108,1,9)<>'left'
    or public.battle_winner(battle.player_left,battle.player_right,108,109,9,1)<>'right' then
    raise exception 'Incorrect score comparison';
  end if;
  select rank_points into left_before from public.public_profiles where id=battle.player_left;
  select rank_points into right_before from public.public_profiles where id=battle.player_right;
  update public.daily_battles set result='draw',left_points=108,right_points=108,
    left_greens=9,right_greens=1,settled_at=now() where id=battle.id;
  select left_rank_delta,right_rank_delta into left_after,right_after
    from public.daily_battles where id=battle.id;
  if left_after<>0 or right_after<>0 then raise exception 'A draw changed ranking delta'; end if;
  if (select rank_points from public.public_profiles where id=battle.player_left)<>left_before
    or (select rank_points from public.public_profiles where id=battle.player_right)<>right_before then
    raise exception 'A draw changed ranking points';
  end if;
end;$$;
rollback;
