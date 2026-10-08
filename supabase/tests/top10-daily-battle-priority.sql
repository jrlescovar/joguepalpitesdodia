-- Run after the migration, inside a transaction that ALWAYS rolls back.
do $$
declare d date:=public.battle_today()+1; people uuid[]; required uuid[]; plan jsonb;
 i integer; attempt integer; gap integer; before_round jsonb; after_round jsonb; baseline jsonb;
begin
 perform pg_advisory_xact_lock(hashtext('daily-battle-round-' || d::text));
 perform pg_advisory_xact_lock(hashtext('daily-battle-final-' || d::text));
 -- Real leaderboard: verify tomorrow's draw, but persist none of these fights.
 delete from public.daily_battles where day_id=d;
 delete from public.daily_battle_reserved_pairings where day_id=d;
 delete from public.daily_battle_rounds where day_id=d;
 select jsonb_agg(jsonb_build_array(id,rank_points,xp,green,red,battle_wins,battle_losses,battle_draws) order by id) into baseline from public.public_profiles;
 perform public.ensure_daily_battle_round(d);
 if exists(select 1 from (select id from public.public_profiles order by rank_points desc,player_id limit 10) top10
  where not exists(select 1 from public.daily_battles b where b.day_id=d and b.player_right is not null and (b.player_left=top10.id or b.player_right=top10.id))) then raise exception 'Real top 10 not covered'; end if;
 if baseline is distinct from (select jsonb_agg(jsonb_build_array(id,rank_points,xp,green,red,battle_wins,battle_losses,battle_draws) order by id) from public.public_profiles) then raise exception 'Draw changed points or statistics'; end if;
 -- Today is already settled; helper must not rewrite its scores or opponents.
 select jsonb_agg(to_jsonb(b) order by id) into before_round from public.daily_battles b where day_id=public.battle_today();
 perform public.pair_top10_daily_battles(public.battle_today());
 select jsonb_agg(to_jsonb(b) order by id) into after_round from public.daily_battles b where day_id=public.battle_today();
 if before_round is distinct from after_round then raise exception 'Today changed'; end if;

 select array_agg(gen_random_uuid()) into people from generate_series(1,12);
 -- Pure planner: it must reserve the scarce candidate rather than use it twice.
 required:=people[1:2];
 plan:=public.plan_priority_battle_pairs(required,people[1:4],jsonb_build_object(people[1]::text,jsonb_build_array(people[3],people[4]),people[2]::text,jsonb_build_array(people[3])));
 if jsonb_array_length(plan)<>2 or not plan @> jsonb_build_array(jsonb_build_object('left',people[1],'right',people[4])) then raise exception 'Scarce rival lost'; end if;
 -- Backtrack a triangle with an attached leaf: choosing 1-2 strands 3 and 4.
 plan:=public.plan_priority_battle_pairs(people[1:4],people[1:4],jsonb_build_object(
  people[1]::text,jsonb_build_array(people[2],people[4]),people[2]::text,jsonb_build_array(people[1],people[3]),
  people[3]::text,jsonb_build_array(people[2],people[4]),people[4]::text,jsonb_build_array(people[1],people[3])));
 if jsonb_array_length(plan)<>2 then raise exception 'Alternate matching not explored'; end if;
 for i in 1..12 loop
  insert into public.public_profiles(id,player_id,username,avatar_color,rank_points,battle_protected,created_at)
   values(people[i],99001200+i,'prio'||substr(people[i]::text,1,8),'#3b82f6',50000+(12-i)*50,true,now()-interval '10 days');
 end loop;
 -- Exclude ordinary real players only in this rollback fixture. The top 10
 -- now consists of fixtures; no fixed account list exists in the implementation.
 update public.public_profiles set created_at=(d+1)::timestamptz where not(id=any(people));
 update public.public_profiles set created_at=now() where id=people[10];
 for attempt in 1..20 loop
  delete from public.daily_battles where day_id=d;
  delete from public.daily_battle_rounds where day_id=d;
  -- Yesterday excludes one pair, including when left/right are reversed.
  if attempt=1 then insert into public.daily_battles(day_id,player_left,player_right) values(d-1,people[1],people[2]); end if;
  perform public.ensure_daily_battle_round(d);
  if exists(select 1 from unnest(people[1:10]) leader(id) where not exists(select 1 from public.daily_battles b where b.day_id=d and b.player_right is not null and (b.player_left=leader.id or b.player_right=leader.id))) then raise exception 'Top10 vacancy at draw %',attempt; end if;
  if exists(select 1 from public.daily_battles b where day_id=d and player_right is not null and
   (not public.daily_battle_opponents_allowed(d,player_left,player_right) or abs(left_start_rank_points::bigint-right_start_rank_points::bigint)>500)) then raise exception 'Draw bypassed constraints'; end if;
  if exists(select id from (select player_left id from public.daily_battles where day_id=d union all select player_right from public.daily_battles where day_id=d and player_right is not null) participants group by id having count(*)>1) then raise exception 'Duplicate fighter'; end if;
  if exists(select 1 from public.daily_battles where day_id=d and (player_left=any(people[11:12]) or player_right=any(people[11:12]))) then raise exception 'Ordinary inactivity rule bypassed'; end if;
  select jsonb_agg(to_jsonb(b) order by id) into before_round from public.daily_battles b where day_id=d;
  perform public.ensure_daily_battle_round(d);
  select jsonb_agg(to_jsonb(b) order by id) into after_round from public.daily_battles b where day_id=d;
  if before_round is distinct from after_round then raise exception 'Repeated draw changed fights'; end if;
 end loop;
 -- Gap 500 is valid and 501 is excluded by the priority pass as well.
 delete from public.daily_battles where day_id=d;
 insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,people[3],50000),(d,people[4],50500);
 -- Mark other leaders settled so this test isolates the two vacancies.
 insert into public.daily_battles(day_id,player_left,result,settled_at) select d,id,'no_contest',now() from unnest(people[1:10]) p(id) where id not in(people[3],people[4]);
 perform public.pair_top10_daily_battles(d);
 if not exists(select 1 from public.daily_battles where day_id=d and player_right is not null) then raise exception '500 boundary excluded'; end if;
 delete from public.daily_battles where day_id=d and player_right is not null;
 insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,people[3],50000),(d,people[4],50501);
 perform public.pair_top10_daily_battles(d);
 if exists(select 1 from public.daily_battles where day_id=d and player_right is not null) then raise exception '501 boundary accepted'; end if;
 -- Reservations remain intact; the remaining eight leaders still get paired.
 delete from public.daily_battles where day_id=d;
 delete from public.daily_battle_rounds where day_id=d;
 insert into public.daily_battle_reserved_pairings(day_id,player_left,player_right) values(d,people[1],people[3]);
 perform public.ensure_daily_battle_round(d);
 if not exists(select 1 from public.daily_battles where day_id=d and player_left=people[1] and player_right=people[3]) then raise exception 'Reserved pair lost'; end if;
 if (select count(*) from public.daily_battles where day_id=d and player_right is not null)<>5 then raise exception 'Reservation stranded another leader'; end if;
 -- Ordinary players still get the same 200/300/400/500 fallback and late-entry
 -- behavior. Completed leaders above are untouched by these vacancy fills.
 delete from public.daily_battles where day_id=d;
 insert into public.daily_battles(day_id,player_left,result,settled_at) select d,id,'no_contest',now() from unnest(people[1:10]) p(id);
 update public.public_profiles set battle_protected=false,rank_points=0 where id=people[11];
 update public.public_profiles set rank_points=0 where id=people[12];
 foreach gap in array array[200,201,300,301,400,401,500,501] loop
  delete from public.daily_battles where day_id=d and player_left=any(people[11:12]);
  insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,people[11],0),(d,people[12],gap);
  perform public.pair_waiting_daily_battles(d);
  if (gap<=500) is distinct from exists(select 1 from public.daily_battles where day_id=d and player_right is not null) then raise exception 'Ordinary fallback changed at %',gap; end if;
  delete from public.daily_battles where day_id=d and player_left=any(people[11:12]);
  insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,people[12],gap);
  perform public.join_daily_battle_bye(people[11],d);
  if (gap<=500) is distinct from exists(select 1 from public.daily_battles where day_id=d and player_right=people[11]) then raise exception 'Ordinary late entry changed at %',gap; end if;
 end loop;
 if has_function_privilege('authenticated','public.pair_top10_daily_battles(date)','execute')
  or has_function_privilege('anon','public.plan_priority_battle_pairs(uuid[],uuid[],jsonb)','execute') then raise exception 'Private functions exposed'; end if;
end;
$$;
select 'PASS: real top 10, 20 priority draws, inactivity override only for top 10, yesterday exclusion, 500 ceiling, immutable fights, no points/stat changes; all rolled back' as result;
