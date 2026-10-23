begin;

-- Masters share an open band; below it the ordinary fallback ends at 500.
create or replace function public.battle_gap_allowed(a integer,b integer,max_gap integer default 500)
returns boolean language sql immutable set search_path=public,pg_temp as $$
 select (a>=2100 and b>=2100) or abs(a::bigint-b::bigint)<=max_gap;
$$;
revoke all on function public.battle_gap_allowed(integer,integer,integer) from public,anon,authenticated;
create or replace function public.battle_compatible(a integer,b integer)
returns boolean language sql immutable set search_path=public,pg_temp as $$
 select (a>=2100 and b>=2100) or abs(a::bigint-b::bigint)<=200;
$$;

-- Keep assigned/finished fights. Plan complete top-10 coverage before writing.
create or replace function public.pair_top10_daily_battles(p_day date)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare leaders uuid[]; required uuid[]; available uuid[]; edges jsonb; plan jsonb; pairing jsonb;
 phase integer; covered integer; left_id bigint; right_id bigint; left_player uuid; right_player uuid; right_start integer;
begin
 if p_day<public.battle_today() or p_day>public.battle_today()+1 then return; end if;
 perform pg_advisory_xact_lock(hashtext('daily-battle-round-' || p_day::text));
 perform pg_advisory_xact_lock(hashtext('daily-battle-final-' || p_day::text));
 if not exists(select 1 from public.daily_battle_rounds where day_id=p_day) then return; end if;
 if exists(select 1 from public.predictions where day_id=p_day)
  and not exists(select 1 from public.predictions where day_id=p_day and status<>'settled') then return; end if;
 select array_agg(id order by rank_points desc,player_id) into leaders from
  (select id,rank_points,player_id from public.public_profiles order by rank_points desc,player_id limit 10) ranked;
 insert into public.daily_battles(day_id,player_left)
  select p_day,leader_id from unnest(leaders) leaders_list(leader_id) where not exists(
   select 1 from public.daily_battles b where b.day_id=p_day and (b.player_left=leader_id or b.player_right=leader_id));
 select coalesce(array_agg(b.player_left),'{}'::uuid[]) into available from public.daily_battles b
  where b.day_id=p_day and b.result='open' and b.player_right is null;
 select coalesce(array_agg(id),'{}'::uuid[]) into required from unnest(leaders) leader(id) where id=any(available);
 if cardinality(required)=0 then return; end if;
 for phase in 1..3 loop
  -- Only if the existing pool cannot cover the leaders, recruit an unassigned
  -- registered player. No unused standby rows or protection changes are saved.
  if phase=3 then
   select array_agg(id) into available from (
    select unnest(available) as id union
    select p.id from public.public_profiles p
    where timezone('America/Sao_Paulo',p.created_at)::date<p_day
     and not exists(select 1 from public.daily_battles b where b.day_id=p_day and (b.player_left=p.id or b.player_right=p.id))
   ) expanded;
  end if;
  with pool as (
   select p.id,coalesce(b.left_start_rank_points,p.rank_points) points,b.id waiting_id
   from public.public_profiles p left join public.daily_battles b
    on b.day_id=p_day and b.player_left=p.id and b.result='open' and b.player_right is null
   where p.id=any(available)
  ), adjacency as (
   select l.id::text fighter,jsonb_agg(r.id order by
    case when public.battle_gap_allowed(l.points,r.points,500) then 0 else 1 end,
    case when r.waiting_id is null then 1 else 0 end,
    case when r.id=any(required) then 0 else 1 end,
    ceil(abs(l.points::bigint-r.points::bigint)/100.0),random()) candidates
   from pool l join pool r on r.id<>l.id where l.id=any(required)
    and (phase>1 or public.battle_gap_allowed(l.points,r.points,500))
    and public.daily_battle_opponents_allowed(p_day,l.id,r.id)
   group by l.id
  ) select coalesce(jsonb_object_agg(fighter,candidates),'{}'::jsonb) into edges from adjacency;
  plan:=public.plan_priority_battle_pairs(required,available,edges);
  select count(*) into covered from jsonb_array_elements(plan) pair,
   lateral (values((pair->>'left')::uuid),((pair->>'right')::uuid)) players(id) where id=any(required);
  exit when covered=cardinality(required);
 end loop;
 for pairing in select value from jsonb_array_elements(plan) loop
  left_player:=(pairing->>'left')::uuid; right_player:=(pairing->>'right')::uuid;
  select id into left_id from public.daily_battles where day_id=p_day and player_left=left_player and result='open' and player_right is null for update;
  select id,left_start_rank_points into right_id,right_start from public.daily_battles where day_id=p_day and player_left=right_player and result='open' and player_right is null for update;
  if right_id is null and not exists(select 1 from public.daily_battles where day_id=p_day and (player_left=right_player or player_right=right_player)) then
   insert into public.daily_battles(day_id,player_left) values(p_day,right_player) returning id,left_start_rank_points into right_id,right_start;
  end if;
  if left_id is null or right_id is null then raise exception 'Priority pairing changed concurrently'; end if;
  delete from public.daily_battles where id=right_id;
  update public.daily_battles set player_right=right_player,right_start_rank_points=right_start where id=left_id;
 end loop;
end;
$$;
revoke all on function public.pair_top10_daily_battles(date) from public,anon,authenticated;

-- Initial/late-entry passes already use battle_compatible. Reservations must
-- use the same open Master band. Never relax yesterday's exclusion.
do $$
declare definition text; anchor text:='abs(l.rank_points::bigint-q.rank_points::bigint)<=500';
begin
 definition:=pg_get_functiondef('public.ensure_daily_battle_round(date)'::regprocedure);
 if position(anchor in definition)=0 then raise exception 'Unexpected reserved draw definition'; end if;
 execute replace(definition,anchor,'public.battle_gap_allowed(l.rank_points,q.rank_points,500)');
end $$;
revoke all on function public.ensure_daily_battle_round(date),public.pair_waiting_daily_battles(date),public.join_daily_battle_bye(uuid,date) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
