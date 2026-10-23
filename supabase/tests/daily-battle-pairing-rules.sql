begin;
-- All fixtures and draws are rolled back; existing results and totals survive.
do $$
declare d date:=public.battle_today()+1; people uuid[]; baseline jsonb; after_state jsonb; saved_today jsonb;
 before_round jsonb; after_round jsonb; n integer; attempt integer; gap integer; plan jsonb; historic jsonb;
begin
 perform pg_advisory_xact_lock(hashtext('daily-battle-round-' || d::text));
 perform pg_advisory_xact_lock(hashtext('daily-battle-final-' || d::text));
 if not public.battle_gap_allowed(1990,1530) or not public.battle_gap_allowed(2000,1500)
  or public.battle_gap_allowed(2000,1499) or public.battle_gap_allowed(2099,2700)
  or not public.battle_gap_allowed(2100,5000) or not public.battle_compatible(5000,2100)
  or not public.battle_gap_allowed(2100,1600) or public.battle_gap_allowed(2100,1599)
 then raise exception '500/Master boundaries wrong'; end if;
 select jsonb_agg(to_jsonb(b) order by id) into saved_today from public.daily_battles b where day_id=public.battle_today();
 select jsonb_agg(jsonb_build_array(id,rank_points,xp,green,red,battle_wins,battle_losses,battle_draws) order by id) into baseline from public.public_profiles;
 delete from public.daily_battles where day_id=d;
 delete from public.daily_battle_reserved_pairings where day_id=d;
 delete from public.daily_battle_rounds where day_id=d;
 perform public.ensure_daily_battle_round(d);
 if exists(select 1 from (select id from public.public_profiles order by rank_points desc,player_id limit 10) leader
  where not exists(select 1 from public.daily_battles b where b.day_id=d and b.player_right is not null and (b.player_left=leader.id or b.player_right=leader.id))) then raise exception 'Real top 10 stranded'; end if;
 if exists(select 1 from public.daily_battles b where b.day_id=d and b.player_right is not null and not public.daily_battle_opponents_allowed(d,b.player_left,b.player_right)) then raise exception 'Yesterday repeat'; end if;
 perform public.pair_top10_daily_battles(public.battle_today());
 if saved_today is distinct from (select jsonb_agg(to_jsonb(b) order by id) from public.daily_battles b where day_id=public.battle_today()) then raise exception 'Finished today changed'; end if;
 if baseline is distinct from (select jsonb_agg(jsonb_build_array(id,rank_points,xp,green,red,battle_wins,battle_losses,battle_draws) order by id) from public.public_profiles) then raise exception 'Real draw changed totals'; end if;
 select jsonb_agg(to_jsonb(b) order by id) into before_round from public.daily_battles b where day_id=d;
 perform public.ensure_daily_battle_round(d);
 if before_round is distinct from (select jsonb_agg(to_jsonb(b) order by id) from public.daily_battles b where day_id=d) then raise exception 'Non-idempotent draw'; end if;

 select array_agg(gen_random_uuid()) into people from generate_series(1,12);
 -- Only ten fixture leaders enter the normal pool; standby 11/12 are protected.
 update public.public_profiles set rank_points=0,created_at=(d+1)::timestamptz;
 for n in 1..12 loop
  insert into public.public_profiles(id,player_id,username,avatar_color,rank_points,battle_protected,created_at)
  values(people[n],99002000+n,'mtch'||substr(people[n]::text,1,8),'#3b82f6',case when n<=10 then 2000-(n-1)*100 else 100 end,true,now()-interval '10 days');
 end loop;
 delete from public.daily_battles where day_id=d;
 delete from public.daily_battle_reserved_pairings where day_id=d;
 delete from public.daily_battle_rounds where day_id=d;
 insert into public.daily_battles(day_id,player_left,player_right) values(d-1,people[1],people[2]);
 for attempt in 1..20 loop
  delete from public.daily_battles where day_id=d;
  delete from public.daily_battle_rounds where day_id=d;
  perform public.ensure_daily_battle_round(d);
  if exists(select 1 from unnest(people[1:10]) leader(id) where not exists(select 1 from public.daily_battles b where b.day_id=d and b.player_right is not null and (b.player_left=leader.id or b.player_right=leader.id))) then raise exception 'Top10 vacancy in draw %',attempt; end if;
  if exists(select 1 from public.daily_battles where day_id=d and player_right is not null and not public.daily_battle_opponents_allowed(d,player_left,player_right)) then raise exception 'Consecutive opponent in draw %',attempt; end if;
  if exists(select id from (select player_left id from public.daily_battles where day_id=d union all select player_right from public.daily_battles where day_id=d and player_right is not null) players group by id having count(*)>1) then raise exception 'Duplicate fighter'; end if;
  if exists(select 1 from public.daily_battles where day_id=d and (player_left=any(people[11:12]) or player_right=any(people[11:12]))) then raise exception 'Unnecessary protected recruit'; end if;
 end loop;
 -- Isolated leaders: the last pair is 2000 vs 1100, beyond the ordinary ceiling.
 delete from public.daily_battles where day_id=d;
 insert into public.daily_battles(day_id,player_left,result,settled_at) select d,id,'no_contest',now() from unnest(people[2:9]) p(id);
 insert into public.daily_battles(day_id,player_left) values(d,people[1]),(d,people[10]);
 perform public.pair_top10_daily_battles(d);
 if not exists(select 1 from public.daily_battles where day_id=d and least(player_left,player_right)=least(people[1],people[10]) and greatest(player_left,player_right)=greatest(people[1],people[10])) then raise exception '2000 vs 1100 rescue missed'; end if;
 select jsonb_agg(to_jsonb(b) order by id) into before_round from public.daily_battles b where day_id=d;
 perform public.pair_top10_daily_battles(d);
 if before_round is distinct from (select jsonb_agg(to_jsonb(b) order by id) from public.daily_battles b where day_id=d) then raise exception 'Assigned rescue changed'; end if;
 -- One leader remains, only unassigned protected accounts can complete its fight.
 delete from public.daily_battles where day_id=d;
 insert into public.daily_battles(day_id,player_left,result,settled_at) select d,id,'no_contest',now() from unnest(people[2:10]) p(id);
 insert into public.daily_battles(day_id,player_left) values(d,people[1]);
 perform public.pair_top10_daily_battles(d);
 if not exists(select 1 from public.daily_battles where day_id=d and player_left=people[1] and player_right=any(people[11:12])) then raise exception 'Emergency pool missed'; end if;
 if (select count(*) from public.daily_battles where day_id=d and (player_left=any(people[11:12]) or player_right=any(people[11:12])))<>1 then raise exception 'Unused standby saved'; end if;
 if not (select bool_and(battle_protected) from public.public_profiles where id=any(people[11:12])) then raise exception 'Protection flags changed'; end if;
 -- Ordinary nonleaders keep 500 maximum; Masters are unlimited in both paths.
 update public.public_profiles set battle_protected=false,rank_points=0 where id=any(people[11:12]);
 foreach gap in array array[200,201,300,301,400,401,500,501] loop
  delete from public.daily_battles where day_id=d;
  insert into public.daily_battles(day_id,player_left,result,settled_at) select d,id,'no_contest',now() from unnest(people[1:10]) p(id);
  update public.public_profiles set rank_points=gap where id=people[12];
  insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,people[11],0),(d,people[12],gap);
  perform public.pair_waiting_daily_battles(d);
  if (gap<=500) is distinct from exists(select 1 from public.daily_battles where day_id=d and player_right is not null) then raise exception 'Ordinary gap %',gap; end if;
  delete from public.daily_battles where day_id=d and player_left=any(people[11:12]);
  insert into public.daily_battles(day_id,player_left,left_start_rank_points) values(d,people[12],gap);
  perform public.join_daily_battle_bye(people[11],d);
  if (gap<=500) is distinct from exists(select 1 from public.daily_battles where day_id=d and player_right=people[11]) then raise exception 'Late gap %',gap; end if;
 end loop;
 -- Keep fixture leaders above the Master pair, so this exercises the ordinary pass.
 update public.public_profiles set rank_points=10000 where id=any(people[1:10]);
 update public.public_profiles set rank_points=case when id=people[11] then 2100 else 5000 end where id=any(people[11:12]);
 delete from public.daily_battles where day_id=d;
 insert into public.daily_battles(day_id,player_left,result,settled_at) select d,id,'no_contest',now() from unnest(people[1:10]) p(id);
 insert into public.daily_battles(day_id,player_left) values(d,people[11]),(d,people[12]);
 perform public.pair_waiting_daily_battles(d);
 if not exists(select 1 from public.daily_battles where day_id=d and player_right is not null) then raise exception 'Masters ordinary pass limited'; end if;
 delete from public.daily_battles where day_id=d and player_left=any(people[11:12]);
 insert into public.daily_battles(day_id,player_left) values(d,people[12]);
 perform public.join_daily_battle_bye(people[11],d);
 if not exists(select 1 from public.daily_battles where day_id=d and player_right=people[11]) then raise exception 'Masters late entry limited'; end if;
 -- A reserved Master pair obeys the same unlimited band as the ordinary draw.
 delete from public.daily_battles where day_id=d;
 delete from public.daily_battle_rounds where day_id=d;
 insert into public.daily_battle_reserved_pairings(day_id,player_left,player_right) values(d,people[11],people[12]);
 perform public.ensure_daily_battle_round(d);
 if not exists(select 1 from public.daily_battles where day_id=d and player_left=people[11] and player_right=people[12]) then raise exception 'Master reservation rejected'; end if;
 -- Direct reversed writes cannot bypass yesterday, even for a top-10 rescue.
 delete from public.daily_battles where day_id=d;
 begin
  insert into public.daily_battles(day_id,player_left,player_right) values(d,people[2],people[1]);
  raise exception 'Repeated opponent accepted';
 exception when check_violation then null;
 end;
 if has_function_privilege('authenticated','public.pair_top10_daily_battles(date)','execute') or has_function_privilege('anon','public.battle_gap_allowed(integer,integer,integer)','execute') then raise exception 'Private helpers exposed'; end if;
end $$;
select 'PASS: real top10, 20 draws, 1990/1530, 500/501, open 2100+ band, 2000/1100 rescue, emergency pool, late entry, no consecutive/duplicate fights, immutable assigned/finished matches, unchanged totals and ACLs' as checks;
rollback;
