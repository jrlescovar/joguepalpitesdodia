begin;

-- Plan first: do not consume the only valid opponent of another top-10 player.
-- This helper reads no tables, writes no matches, and recurses at most 10 levels.
create function public.plan_priority_battle_pairs(required uuid[], available uuid[], edges jsonb)
returns jsonb language plpgsql immutable set search_path=public,pg_temp as $$
declare fighter uuid; rival uuid; next_required uuid[]; remaining uuid[];
 candidate jsonb; best jsonb:='[]'::jsonb; covered integer; best_covered integer:=-1;
begin
 if cardinality(required)=0 then return best; end if;
 select p into fighter from unnest(required) p order by
  (select count(*) from jsonb_array_elements_text(coalesce(edges->p::text,'[]'::jsonb)) r where r::uuid=any(available)),p limit 1;
 next_required:=array_remove(required,fighter); remaining:=array_remove(available,fighter);
 for rival in select r::uuid from jsonb_array_elements_text(coalesce(edges->fighter::text,'[]'::jsonb)) r where r::uuid=any(remaining) loop
  candidate:=jsonb_build_array(jsonb_build_object('left',fighter,'right',rival)) ||
   public.plan_priority_battle_pairs(array_remove(next_required,rival),array_remove(remaining,rival),edges);
  select count(*) into covered from jsonb_array_elements(candidate) pair,
   lateral (values((pair->>'left')::uuid),((pair->>'right')::uuid)) players(id) where id=any(required);
  if covered>best_covered then best:=candidate; best_covered:=covered; end if;
  if covered=cardinality(required) then return best; end if;
 end loop;
 -- Preserve yesterday's exclusion and the 500-point ceiling if full coverage
 -- is mathematically impossible; choose the maximum achievable coverage.
 candidate:=public.plan_priority_battle_pairs(next_required,remaining,edges);
 select count(*) into covered from jsonb_array_elements(candidate) pair,
  lateral (values((pair->>'left')::uuid),((pair->>'right')::uuid)) players(id) where id=any(required);
 if covered>best_covered then best:=candidate; end if;
 return best;
end;
$$;
revoke all on function public.plan_priority_battle_pairs(uuid[],uuid[],jsonb) from public,anon,authenticated;

create function public.pair_top10_daily_battles(p_day date)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare leaders uuid[]; required uuid[]; available uuid[]; edges jsonb; plan jsonb; pairing jsonb;
 left_id bigint; right_id bigint; left_player uuid; right_player uuid; right_start integer;
begin
 if p_day<public.battle_today() or p_day>public.battle_today()+1 then return; end if;
 perform pg_advisory_xact_lock(hashtext('daily-battle-round-' || p_day::text));
 perform pg_advisory_xact_lock(hashtext('daily-battle-final-' || p_day::text));
 if not exists(select 1 from public.daily_battle_rounds where day_id=p_day) then return; end if;
 if exists(select 1 from public.predictions where day_id=p_day)
  and not exists(select 1 from public.predictions where day_id=p_day and status<>'settled') then return; end if;
 -- Same ordering as the public top 10. Inactivity and account age do not
 -- exclude these ten; other players retain their existing eligibility rules.
 select array_agg(id order by rank_points desc,player_id) into leaders from
  (select id,rank_points,player_id from public.public_profiles order by rank_points desc,player_id limit 10) ranked;
 insert into public.daily_battles(day_id,player_left)
  select p_day,leader_id from unnest(leaders) leaders_list(leader_id) where not exists(
   select 1 from public.daily_battles b where b.day_id=p_day and (b.player_left=leader_id or b.player_right=leader_id));
 select coalesce(array_agg(b.player_left),'{}'::uuid[]) into available from public.daily_battles b
  where b.day_id=p_day and b.result='open' and b.player_right is null;
 select coalesce(array_agg(id),'{}'::uuid[]) into required from unnest(leaders) id where id=any(available);
 if cardinality(required)=0 then return; end if;
 select coalesce(jsonb_object_agg(fighter,candidates),'{}'::jsonb) into edges from (
  select l.player_left::text fighter,jsonb_agg(r.player_left order by
   case when r.player_left=any(required) then 0 else 1 end,
   ceil(abs(l.left_start_rank_points::bigint-r.left_start_rank_points::bigint)/100.0),random()) candidates
  from public.daily_battles l join public.daily_battles r on r.day_id=l.day_id and r.player_left<>l.player_left
  where l.day_id=p_day and l.player_left=any(required) and r.player_left=any(available)
   and l.result='open' and r.result='open' and l.player_right is null and r.player_right is null
   and abs(l.left_start_rank_points::bigint-r.left_start_rank_points::bigint)<=500
   and public.daily_battle_opponents_allowed(p_day,l.player_left,r.player_left)
  group by l.player_left
 ) adjacency;
 plan:=public.plan_priority_battle_pairs(required,available,edges);
 for pairing in select value from jsonb_array_elements(plan) loop
  left_player:=(pairing->>'left')::uuid; right_player:=(pairing->>'right')::uuid;
  select id into left_id from public.daily_battles where day_id=p_day and player_left=left_player and result='open' and player_right is null for update;
  select id,left_start_rank_points into right_id,right_start from public.daily_battles where day_id=p_day and player_left=right_player and result='open' and player_right is null for update;
  if left_id is null or right_id is null then raise exception 'Priority pairing changed concurrently'; end if;
  delete from public.daily_battles where id=right_id;
  update public.daily_battles set player_right=right_player,right_start_rank_points=right_start where id=left_id;
 end loop;
end;
$$;
revoke all on function public.pair_top10_daily_battles(date) from public,anon,authenticated;

-- Hook into future draws/late-entry requests; no invocation in this migration.
-- Assigned opponents and closed results are never redrawn.
do $$
declare definition text; anchor text;
begin
 definition:=pg_get_functiondef('public.pair_waiting_daily_battles(date)'::regprocedure);
 anchor:='foreach max_gap in array array[200,300,400,500] loop';
 if position(anchor in definition)=0 then raise exception 'Unexpected fallback definition'; end if;
 execute replace(definition,anchor,'perform public.pair_top10_daily_battles(p_day);' || chr(10) || anchor);
 definition:=pg_get_functiondef('public.join_daily_battle_bye(uuid,date)'::regprocedure);
 anchor:='if exists(select 1 from public.daily_battles where day_id=p_day and (player_left=p_profile or player_right=p_profile)) then return; end if;';
 if position(anchor in definition)=0 then raise exception 'Unexpected late-entry definition'; end if;
 definition:=replace(definition,anchor,'perform public.pair_top10_daily_battles(p_day);' || chr(10) || anchor);
 definition:=replace(definition,'order by random() limit 1 for update of b;',
  'order by case when b.player_left in (select id from public.public_profiles order by rank_points desc,player_id limit 10) then 0 else 1 end,random() limit 1 for update of b;');
 execute definition;
end;
$$;

create or replace function public.ensure_daily_battle_round(p_day date)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare leaders uuid[];
begin
 if p_day<date '2026-09-26' or p_day>public.battle_today()+1 then return; end if;
 perform pg_advisory_xact_lock(hashtext('daily-battle-round-' || p_day::text));
 if exists(select 1 from public.daily_battle_rounds where day_id=p_day) then
  perform public.pair_waiting_daily_battles(p_day); return;
 end if;
 perform public.finalize_daily_battle(p_day-1);
 perform public.refresh_battle_activity(p_day);
 insert into public.daily_battle_rounds(day_id) values(p_day);
 insert into public.daily_battles(day_id,player_left,player_right)
  select r.day_id,r.player_left,r.player_right from public.daily_battle_reserved_pairings r
  join public.public_profiles l on l.id=r.player_left join public.public_profiles q on q.id=r.player_right
  where r.day_id=p_day and public.daily_battle_opponents_allowed(p_day,r.player_left,r.player_right)
   and abs(l.rank_points::bigint-q.rank_points::bigint)<=500;
 select array_agg(id) into leaders from (select id from public.public_profiles order by rank_points desc,player_id limit 10) ranked;
 insert into public.daily_battles(day_id,player_left)
  select p_day,p.id from public.public_profiles p
  where ((not p.battle_protected and timezone('America/Sao_Paulo',p.created_at)::date<p_day) or p.id=any(leaders))
   and not exists(select 1 from public.daily_battles b where b.day_id=p_day and (b.player_left=p.id or b.player_right=p.id))
  order by random();
 perform public.pair_waiting_daily_battles(p_day);
end;
$$;
revoke all on function public.ensure_daily_battle_round(date),public.pair_waiting_daily_battles(date),public.join_daily_battle_bye(uuid,date) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
