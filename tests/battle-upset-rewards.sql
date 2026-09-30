begin;
do $$
declare d date:=date '2071-02-02'; low uuid:=gen_random_uuid(); high uuid:=gen_random_uuid();
  same_a uuid:=gen_random_uuid(); same_b uuid:=gen_random_uuid(); high_a uuid:=gen_random_uuid(); low_b uuid:=gen_random_uuid();
begin
  if public.battle_rank_tier(99)<>1 or public.battle_rank_tier(100)<>2
    or public.battle_rank_tier(250)<>2 or public.battle_rank_tier(251)<>3
    or public.battle_rank_tier(2100)<>10 then raise exception 'Patent thresholds drifted'; end if;
  insert into public.public_profiles(id,player_id,username,avatar_color,rank_points) values
    (low,99000301,'upsetbronze','#3b82f6',80),(high,99000302,'upsetgold','#3b82f6',300),
    (same_a,99000303,'samebronzea','#3b82f6',80),(same_b,99000304,'samebronzeb','#3b82f6',80),
    (high_a,99000305,'winhigher','#3b82f6',300),(low_b,99000306,'losebronze','#3b82f6',80);
  insert into public.daily_battle_rounds(day_id) values(d);
  insert into public.daily_battles(day_id,player_left,player_right) values
    (d,low,high),(d,same_a,same_b),(d,high_a,low_b);
  if not exists(select 1 from public.daily_battles where day_id=d and player_left=low
    and left_start_rank_points=80 and right_start_rank_points=300) then
    raise exception 'Matchup patent snapshot missing';
  end if;
  -- Crossing a patent after the matchup must not change its reward.
  update public.public_profiles set rank_points=260 where id=low;
  if not exists(select 1 from public.daily_battles where day_id=d and player_left=low
    and left_start_rank_points=80 and right_start_rank_points=300
    and public.battle_win_bonus(left_start_rank_points,right_start_rank_points,'left')=25) then
    raise exception 'Matchup patent changed after ranking up';
  end if;
  update public.public_profiles set rank_points=80 where id=low;
  insert into public.predictions(day_id,slot,title,options,closes_at,status,winning_option_id,settled_at)
    values(d,0,'Teste recompensa patente','[{"id":"1","label":"Sim","rankPoints":50},{"id":"2","label":"Não","rankPoints":10}]',now()-interval '1 hour','settled','1',now());
  insert into public.picks(profile_id,prediction_day,slot,option_id,status) values
    (low,d,0,'1','green'),(high,d,0,'2','red'),
    (same_a,d,0,'1','green'),(same_b,d,0,'2','red'),
    (high_a,d,0,'1','green'),(low_b,d,0,'2','red');
  -- Future fixtures are never finalized by the production clock.
  create or replace function public.battle_today() returns date language sql stable as $clock$select date '2071-02-02'$clock$;
  perform public.finalize_daily_battle(d);
  if not exists(select 1 from public.daily_battles where day_id=d and player_left=low
    and result='left' and left_rank_delta=25 and right_rank_delta=-25)
    or not exists(select 1 from public.daily_battles where day_id=d and player_left=same_a
    and result='left' and left_rank_delta=15 and right_rank_delta=-15)
    or not exists(select 1 from public.daily_battles where day_id=d and player_left=high_a
    and result='left' and left_rank_delta=15 and right_rank_delta=-15) then
    raise exception 'Wrong battle bonus by patent';
  end if;
  if not exists(select 1 from public.public_profiles where id=low and rank_points=105)
    or not exists(select 1 from public.public_profiles where id=high and rank_points=275) then
    raise exception 'Upset rank points not applied';
  end if;
  perform public.finalize_daily_battle(d);
  if not exists(select 1 from public.public_profiles where id=low and rank_points=105) then
    raise exception 'Battle points credited twice';
  end if;
  update public.picks set status='red' where profile_id=low and prediction_day=d;
  update public.picks set status='green' where profile_id=high and prediction_day=d;
  if not exists(select 1 from public.daily_battles where day_id=d and player_left=low
    and result='right' and left_rank_delta=-15 and right_rank_delta=15) then
    raise exception 'Correction ignored the patent rule: %',
      (select row_to_json(b) from public.daily_battles b where b.day_id=d and b.player_left=low);
  end if;
end;$$;
rollback;
