begin;
do $$
declare d date:=public.battle_today()+1; people uuid[]:=array[gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
 i integer; g integer; attempt integer; baseline jsonb; after_draw jsonb; prior_results jsonb;
begin
 perform pg_advisory_xact_lock(hashtext('daily-battle-round-' || d::text));
 perform pg_advisory_xact_lock(hashtext('daily-battle-final-' || d::text));
 select jsonb_agg(to_jsonb(b) order by id) into prior_results from public.daily_battles b where day_id=d-1;
 delete from public.daily_battles where day_id=d;
 delete from public.daily_battle_reserved_pairings where day_id=d;
 insert into public.daily_battle_rounds(day_id) values(d) on conflict do nothing;
 for i in 1..4 loop
  insert into public.public_profiles(id,player_id,username,avatar_color,rank_points,battle_protected,created_at)
   values(people[i],99000900+i,'nr'||substr(people[i]::text,1,8),'#3b82f6',0,true,now()-interval '1 day');
 end loop;
 update public.public_profiles set battle_protected=false where id=any(people);
 insert into public.daily_battles(day_id,player_left,player_right) values(d-1,people[1],people[2]),(d-1,people[3],people[4]);
 if public.daily_battle_opponents_allowed(d,people[1],people[2]) or public.daily_battle_opponents_allowed(d,people[2],people[1]) then raise exception 'Orientation bypassed previous-day exclusion'; end if;
 if not public.daily_battle_opponents_allowed(d,people[1],people[3]) then raise exception 'Different rival excluded'; end if;

 -- No gap expansion, including high-rank compatibility, may re-use yesterday.
 foreach g in array array[0,200,284,300,400,500,900] loop
  delete from public.daily_battles where day_id=d;
  insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,people[1],case when g=900 then 900 else 0 end),(d,people[2],case when g=900 then 1800 else g end);
  perform public.pair_waiting_daily_battles(d);
  if (select count(*) from public.daily_battles where day_id=d and player_right is null)<>2 then raise exception 'Fallback repeated opponent at gap %',g; end if;
 end loop;

 -- Late entrant bypasses the closer old rival and may use a valid 400-gap rival.
 delete from public.daily_battles where day_id=d;
 insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,people[1],0),(d,people[3],350);
 perform public.join_daily_battle_bye(people[2],d);
 if not exists(select 1 from public.daily_battles where day_id=d and player_left=people[3] and player_right=people[2]) then raise exception 'Late entrant ignored an alternate rival'; end if;
 if exists(select 1 from public.daily_battles where day_id=d and player_left=people[1] and player_right is not null) then raise exception 'Late entrant repeated rival'; end if;

 -- Direct insert/update cannot bypass the algorithm with reversed orientation.
 delete from public.daily_battles where day_id=d;
 begin
  insert into public.daily_battles(day_id,player_left,player_right) values(d,people[2],people[1]);
  raise exception 'Direct repeated pair accepted';
 exception when check_violation then null;
 end;
 insert into public.daily_battles(day_id,player_left) values(d,people[2]);
 begin
  update public.daily_battles set player_right=people[1] where day_id=d and player_left=people[2];
  raise exception 'Direct repeated pair update accepted';
 exception when check_violation then null;
 end;

 -- Exclude real players only inside this rollback fixture; preserve draw rules.
 update public.public_profiles set created_at=(d+1)::timestamptz where not(id=any(people));
 for attempt in 1..25 loop
  delete from public.daily_battles where day_id=d;
  delete from public.daily_battle_rounds where day_id=d;
  delete from public.daily_battle_reserved_pairings where day_id=d;
  if attempt=1 then
   -- An invalid repeat reservation is skipped and those players join the draw.
   insert into public.daily_battle_reserved_pairings(day_id,player_left,player_right) values(d,people[2],people[1]);
  elsif attempt=2 then
   insert into public.daily_battle_reserved_pairings(day_id,player_left,player_right) values(d,people[1],people[3]);
  end if;
  perform public.ensure_daily_battle_round(d);
  if (select count(*) from public.daily_battles where day_id=d and player_right is not null)<>2 then raise exception 'Valid alternatives were not paired'; end if;
  if exists(select 1 from public.daily_battles b where day_id=d and not public.daily_battle_opponents_allowed(d,b.player_left,b.player_right)) then raise exception 'Full draw repeated previous-day rivals'; end if;
  if attempt=2 and not exists(select 1 from public.daily_battles where day_id=d and player_left=people[1] and player_right=people[3]) then raise exception 'Valid reservation lost'; end if;
  if exists(select participant from(select player_left participant from public.daily_battles where day_id=d union all select player_right from public.daily_battles where day_id=d and player_right is not null) p group by participant having count(*)<>1) then raise exception 'Player entered twice'; end if;
  select jsonb_agg(to_jsonb(b) order by id) into baseline from public.daily_battles b where day_id=d;
  perform public.ensure_daily_battle_round(d);
  select jsonb_agg(to_jsonb(b) order by id) into after_draw from public.daily_battles b where day_id=d;
  if baseline is distinct from after_draw then raise exception 'Repeated ensure redrew battles'; end if;
 end loop;

 -- No alternative means a bye, never a repeated opponent.
 delete from public.daily_battles where day_id=d;
 delete from public.daily_battle_rounds where day_id=d;
 delete from public.daily_battle_reserved_pairings where day_id=d;
 update public.public_profiles set created_at=(d+1)::timestamptz where id in(people[3],people[4]);
 perform public.ensure_daily_battle_round(d);
 if (select count(*) from public.daily_battles where day_id=d and player_right is null)<>2 then raise exception 'Two-player draw repeated an opponent'; end if;

 -- The rule is for consecutive calendar days, not the last opponent ever.
 delete from public.daily_battles where day_id=d or (day_id=d-1 and player_left=any(people));
 insert into public.daily_battles(day_id,player_left,player_right) values(d-2,people[1],people[2]);
 insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,people[1],0),(d,people[2],0);
 perform public.pair_waiting_daily_battles(d);
 if not exists(select 1 from public.daily_battles where day_id=d and player_right is not null) then raise exception 'Nonconsecutive rematch incorrectly excluded'; end if;
 begin
  insert into public.daily_battles(day_id,player_left,player_right) values(d-1,people[2],people[1]);
  raise exception 'Saving adjacent rounds out of order bypassed the rule';
 exception when check_violation then null;
 end;

 select jsonb_agg(to_jsonb(b) order by id) into after_draw from public.daily_battles b where day_id=d-1 and not(player_left=any(people));
 if after_draw is distinct from prior_results then raise exception 'Existing results were modified'; end if;
 if has_function_privilege('authenticated','public.daily_battle_opponents_allowed(date,uuid,uuid)','EXECUTE') or has_function_privilege('anon','public.guard_consecutive_battle_opponents()','EXECUTE') then raise exception 'Internal access exposed'; end if;
end;
$$;
select 'PASS: 25 full draws, reservations, reversed pairs, all fallback gaps, late entrants, byes, idempotency and closed results' as result;
rollback;
