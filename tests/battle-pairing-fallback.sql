begin;
do $$
declare
  d date:=public.battle_today()+1;
  players uuid[]:=array[gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
  g integer; i integer; before_pair jsonb; after_pair jsonb;
begin
  perform pg_advisory_xact_lock(hashtext('daily-battle-round-' || d::text));
  perform pg_advisory_xact_lock(hashtext('daily-battle-final-' || d::text));
  delete from public.daily_battles where day_id=d;
  delete from public.daily_battle_reserved_pairings where day_id=d;
  insert into public.daily_battle_rounds(day_id) values(d) on conflict do nothing;
  for i in 1..6 loop
    insert into public.public_profiles(id,player_id,username,avatar_color,rank_points,battle_protected,created_at)
      values(players[i],99000800+i,'fb'||substr(players[i]::text,1,8),'#3b82f6',0,true,now()-interval '1 day');
  end loop;
  update public.public_profiles set battle_protected=false where id=any(players);

  -- Exact boundaries: 200, 300, 400 and 500 are inclusive, 501 stays unmatched.
  foreach g in array array[200,201,284,300,301,400,401,499,500,501] loop
    delete from public.daily_battles where day_id=d;
    insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,players[1],0),(d,players[2],g);
    perform public.pair_waiting_daily_battles(d);
    if (g<=500 and (select count(*) from public.daily_battles where day_id=d and player_right is not null)<>1)
      or (g>500 and (select count(*) from public.daily_battles where day_id=d and player_right is null)<>2) then
      raise exception 'Wrong pairing boundary: %',g;
    end if;
  end loop;

  -- Finish the 200 pass before expanding it; paired rows remain byte-for-byte.
  delete from public.daily_battles where day_id=d;
  insert into public.daily_battles(day_id,player_left,left_start_rank_points) values
    (d,players[1],0),(d,players[2],300),(d,players[3],500),(d,players[4],900);
  insert into public.daily_battles(day_id,player_left,player_right,left_start_rank_points,right_start_rank_points)
    values(d,players[5],players[6],100,110);
  select to_jsonb(b) into before_pair from public.daily_battles b where day_id=d and player_left=players[5];
  perform public.pair_waiting_daily_battles(d);
  if not exists(select 1 from public.daily_battles where day_id=d and player_left=players[2] and player_right=players[3])
    or (select count(*) from public.daily_battles where day_id=d and player_right is null)<>2 then
    raise exception 'Fallback consumed a 200-point candidate too early';
  end if;
  select to_jsonb(b) into after_pair from public.daily_battles b where day_id=d and player_left=players[5];
  if before_pair is distinct from after_pair then raise exception 'Existing matchup changed'; end if;
  select jsonb_agg(to_jsonb(b) order by id) into before_pair from public.daily_battles b where day_id=d;
  perform public.pair_waiting_daily_battles(d);
  select jsonb_agg(to_jsonb(b) order by id) into after_pair from public.daily_battles b where day_id=d;
  if before_pair is distinct from after_pair then raise exception 'Repeated pairing changed the round'; end if;

  -- The 500 ceiling also applies to 900+ ranks. Keep draw snapshots after gains.
  delete from public.daily_battles where day_id=d;
  insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,players[1],900),(d,players[2],1500);
  perform public.pair_waiting_daily_battles(d);
  if exists(select 1 from public.daily_battles where day_id=d and player_right is not null) then raise exception 'High ranks bypassed the 500 ceiling'; end if;
  delete from public.daily_battles where day_id=d;
  insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,players[1],900),(d,players[2],1400);
  perform public.pair_waiting_daily_battles(d);
  if (select count(*) from public.daily_battles where day_id=d and player_right is not null)<>1 then raise exception 'High-rank 500 boundary failed'; end if;
  delete from public.daily_battles where day_id=d;
  update public.public_profiles set rank_points=1000 where id=players[2];
  insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,players[1],110),(d,players[2],394);
  perform public.pair_waiting_daily_battles(d);
  if not exists(select 1 from public.daily_battles where day_id=d and left_start_rank_points=110 and right_start_rank_points=394) then raise exception 'Draw snapshot not retained'; end if;

  -- A late entrant tries 200 before 300/400/500; completed byes never reopen.
  foreach g in array array[-501,-500,-401,-300,-200,0,200,284,350,401,500,501] loop
    delete from public.daily_battles where day_id=d;
    update public.public_profiles set rank_points=600 where id=players[2];
    insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,players[1],600+g);
    perform public.join_daily_battle_bye(players[2],d);
    if (abs(g)<=500 and not exists(select 1 from public.daily_battles where day_id=d and player_right=players[2]))
      or (abs(g)>500 and exists(select 1 from public.daily_battles where day_id=d and player_right is not null)) then raise exception 'Late entry boundary %',g; end if;
  end loop;
  delete from public.daily_battles where day_id=d;
  update public.public_profiles set rank_points=0 where id=players[2];
  insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,players[1],300),(d,players[3],100);
  perform public.join_daily_battle_bye(players[2],d);
  if not exists(select 1 from public.daily_battles where day_id=d and player_left=players[3] and player_right=players[2]) then raise exception 'Late entry skipped 200-point candidate'; end if;
  delete from public.daily_battles where day_id=d;
  insert into public.daily_battles(day_id,player_left,result,settled_at) values(d,players[1],'no_contest',now()),(d,players[3],'open',null);
  perform public.pair_waiting_daily_battles(d);
  if exists(select 1 from public.daily_battles where day_id=d and player_right is not null) then raise exception 'Settled bye reopened'; end if;

  -- Full draw integration, reservations and repeated ensure calls.
  delete from public.daily_battles where day_id=d;
  delete from public.daily_battle_rounds where day_id=d;
  update public.public_profiles set created_at=(d+1)::timestamptz where not(id=any(players));
  update public.public_profiles set rank_points=case id when players[3] then 0 when players[4] then 284 when players[5] then 700 when players[6] then 1100 else 0 end where id=any(players);
  insert into public.daily_battle_reserved_pairings(day_id,player_left,player_right) values(d,players[1],players[2]);
  perform public.ensure_daily_battle_round(d);
  if (select count(*) from public.daily_battles where day_id=d and player_right is not null)<>3
    or not exists(select 1 from public.daily_battles where day_id=d and player_left=players[1] and player_right=players[2]) then raise exception 'Full draw/reservation integration failed'; end if;
  if exists(select participant from (
    select player_left participant from public.daily_battles where day_id=d
    union all select player_right from public.daily_battles where day_id=d and player_right is not null
  ) participants group by participant having count(*)<>1) then raise exception 'Duplicate participant'; end if;
  select jsonb_agg(to_jsonb(b) order by id) into before_pair from public.daily_battles b where day_id=d;
  perform public.ensure_daily_battle_round(d);
  select jsonb_agg(to_jsonb(b) order by id) into after_pair from public.daily_battles b where day_id=d;
  if before_pair is distinct from after_pair then raise exception 'Ensure changed formed matchups'; end if;

  if has_function_privilege('authenticated','public.pair_waiting_daily_battles(date)','execute')
    or has_function_privilege('anon','public.join_daily_battle_bye(uuid,date)','execute') then raise exception 'Internal pairing exposed'; end if;
end;
$$;
rollback;
