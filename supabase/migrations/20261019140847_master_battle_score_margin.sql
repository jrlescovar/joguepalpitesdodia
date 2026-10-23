begin;


-- Starting ranks fix the rule for the entire matchup. Earlier days keep
-- their existing rewards, including later administrative corrections.
create function public.battle_points_transfer(p_day date,p_left_start integer,p_right_start integer,p_outcome text,p_left_score integer,p_right_score integer)
returns integer language sql immutable set search_path=public,pg_temp as $$
 select case
  when p_outcome not in ('left','right') or p_outcome is null then 0
  when p_day>=date '2026-10-19' and greatest(coalesce(p_left_start,0),coalesce(p_right_start,0))>=2100
   then abs(p_left_score-p_right_score)
  else public.battle_win_bonus(p_left_start,p_right_start,p_outcome)
 end;
$$;
revoke all on function public.battle_points_transfer(date,integer,integer,text,integer,integer) from public,anon,authenticated;

CREATE OR REPLACE FUNCTION public.finalize_daily_battle(p_day date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare battle public.daily_battles; left_score integer; right_score integer; left_hits integer; right_hits integer; outcome text;
begin
  if p_day > public.battle_today() then return; end if;
  perform pg_advisory_xact_lock(hashtext('daily-battle-final-' || p_day::text));
  if not exists (select 1 from public.predictions where day_id=p_day) then return; end if;
  if exists (select 1 from public.predictions where day_id=p_day and status<>'settled') then return; end if;

  for battle in select * from public.daily_battles where day_id=p_day and result='open' for update loop
    select coalesce(sum(case when k.status='green' then coalesce((select (o->>'rankPoints')::integer from jsonb_array_elements(g.options) o where o->>'id'=k.option_id),0) else 0 end),0),
           count(*) filter (where k.status='green')
      into left_score,left_hits
      from public.picks k join public.predictions g on g.day_id=k.prediction_day and g.slot=k.slot
      where k.profile_id=battle.player_left and k.prediction_day=p_day;
    if battle.player_right is null then
      update public.daily_battles set left_points=left_score,left_greens=left_hits,result='no_contest',settled_at=now() where id=battle.id;
      continue;
    end if;
    select coalesce(sum(case when k.status='green' then coalesce((select (o->>'rankPoints')::integer from jsonb_array_elements(g.options) o where o->>'id'=k.option_id),0) else 0 end),0),
           count(*) filter (where k.status='green')
      into right_score,right_hits
      from public.picks k join public.predictions g on g.day_id=k.prediction_day and g.slot=k.slot
      where k.profile_id=battle.player_right and k.prediction_day=p_day;
    perform 1 from public.public_profiles where id in (battle.player_left,battle.player_right) order by id for update;
    outcome := public.battle_winner(battle.player_left,battle.player_right,left_score,right_score,left_hits,right_hits);
    update public.daily_battles set left_points=left_score,right_points=right_score,left_greens=left_hits,right_greens=right_hits,result=outcome,settled_at=now() where id=battle.id;
    update public.public_profiles set
      rank_points=greatest(0,rank_points + case outcome when 'left' then public.battle_points_transfer(battle.day_id,battle.left_start_rank_points,battle.right_start_rank_points,outcome,left_score,right_score) when 'right' then -public.battle_points_transfer(battle.day_id,battle.left_start_rank_points,battle.right_start_rank_points,outcome,left_score,right_score) else 0 end),
      battle_wins=battle_wins + (case when outcome='left' then 1 else 0 end),
      battle_losses=battle_losses + (case when outcome='right' then 1 else 0 end), battle_draws=battle_draws + (case when outcome='draw' then 1 else 0 end),
      updated_at=now()
      where id=battle.player_left;
    update public.public_profiles set
      rank_points=greatest(0,rank_points + case outcome when 'right' then public.battle_points_transfer(battle.day_id,battle.left_start_rank_points,battle.right_start_rank_points,outcome,left_score,right_score) when 'left' then -public.battle_points_transfer(battle.day_id,battle.left_start_rank_points,battle.right_start_rank_points,outcome,left_score,right_score) else 0 end),
      battle_wins=battle_wins + (case when outcome='right' then 1 else 0 end),
      battle_losses=battle_losses + (case when outcome='left' then 1 else 0 end), battle_draws=battle_draws + (case when outcome='draw' then 1 else 0 end),
      updated_at=now()
      where id=battle.player_right;
  end loop;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.record_battle_rank_deltas()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare left_rank integer; right_rank integer; left_bonus integer; right_bonus integer;
begin
 if old.result<>'open' or new.result='open' then return new; end if;
 if new.result='no_contest' then new.left_rank_delta:=0; new.right_rank_delta:=0; return new; end if;
 select rank_points into left_rank from public.public_profiles where id=new.player_left;
 select rank_points into right_rank from public.public_profiles where id=new.player_right;
 left_bonus:=case new.result when 'left' then public.battle_points_transfer(new.day_id,new.left_start_rank_points,new.right_start_rank_points,new.result,new.left_points,new.right_points) when 'right' then -public.battle_points_transfer(new.day_id,new.left_start_rank_points,new.right_start_rank_points,new.result,new.left_points,new.right_points) else 0 end;
 right_bonus:=case new.result when 'right' then public.battle_points_transfer(new.day_id,new.left_start_rank_points,new.right_start_rank_points,new.result,new.left_points,new.right_points) when 'left' then -public.battle_points_transfer(new.day_id,new.left_start_rank_points,new.right_start_rank_points,new.result,new.left_points,new.right_points) else 0 end;
 new.left_rank_delta:=greatest(0,left_rank+left_bonus)-left_rank;
 new.right_rank_delta:=greatest(0,right_rank+right_bonus)-right_rank;
 return new;
end; $function$
;

CREATE OR REPLACE FUNCTION public.reconcile_corrected_battle_pick()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare
  battle public.daily_battles;
  left_score integer; right_score integer; left_hits integer; right_hits integer;
  outcome text; left_base integer; right_base integer;
  left_bonus integer; right_bonus integer; left_next integer; right_next integer;
begin
  if new.status = old.status and new.option_id = old.option_id then return new; end if;
  select * into battle from public.daily_battles
    where day_id = new.prediction_day and (player_left = new.profile_id or player_right = new.profile_id)
      and result in ('left', 'right', 'draw') for update;
  if not found then return new; end if;
  select coalesce(sum(case when k.status = 'green' then coalesce((select (o->>'rankPoints')::integer
    from jsonb_array_elements(g.options) o where o->>'id' = k.option_id), 0) else 0 end), 0),
    count(*) filter (where k.status = 'green')
  into left_score, left_hits from public.picks k
    join public.predictions g on g.day_id = k.prediction_day and g.slot = k.slot
    where k.profile_id = battle.player_left and k.prediction_day = battle.day_id;
  select coalesce(sum(case when k.status = 'green' then coalesce((select (o->>'rankPoints')::integer
    from jsonb_array_elements(g.options) o where o->>'id' = k.option_id), 0) else 0 end), 0),
    count(*) filter (where k.status = 'green')
  into right_score, right_hits from public.picks k
    join public.predictions g on g.day_id = k.prediction_day and g.slot = k.slot
    where k.profile_id = battle.player_right and k.prediction_day = battle.day_id;
  outcome := public.battle_winner(battle.player_left,battle.player_right,left_score,right_score,left_hits,right_hits);
  if outcome = battle.result and public.battle_points_transfer(battle.day_id,battle.left_start_rank_points,battle.right_start_rank_points,outcome,left_score,right_score)
    = public.battle_points_transfer(battle.day_id,battle.left_start_rank_points,battle.right_start_rank_points,battle.result,battle.left_points,battle.right_points) then
    update public.daily_battles set left_points = left_score, right_points = right_score,
      left_greens = left_hits, right_greens = right_hits where id = battle.id;
    return new;
  end if;
  select greatest(0, rank_points - battle.left_rank_delta) into left_base
    from public.public_profiles where id = battle.player_left for update;
  select greatest(0, rank_points - battle.right_rank_delta) into right_base
    from public.public_profiles where id = battle.player_right for update;
  left_bonus := case outcome when 'left' then public.battle_points_transfer(battle.day_id,battle.left_start_rank_points,battle.right_start_rank_points,outcome,left_score,right_score) when 'right' then -public.battle_points_transfer(battle.day_id,battle.left_start_rank_points,battle.right_start_rank_points,outcome,left_score,right_score) else 0 end;
  right_bonus := case outcome when 'right' then public.battle_points_transfer(battle.day_id,battle.left_start_rank_points,battle.right_start_rank_points,outcome,left_score,right_score) when 'left' then -public.battle_points_transfer(battle.day_id,battle.left_start_rank_points,battle.right_start_rank_points,outcome,left_score,right_score) else 0 end;
  left_next := greatest(0, left_base + left_bonus);
  right_next := greatest(0, right_base + right_bonus);
  update public.public_profiles set rank_points = left_next,
    battle_wins = battle_wins + (outcome = 'left')::integer - (battle.result = 'left')::integer,
    battle_losses = battle_losses + (outcome = 'right')::integer - (battle.result = 'right')::integer,
    battle_draws = battle_draws + (outcome = 'draw')::integer - (battle.result = 'draw')::integer,
    updated_at = now() where id = battle.player_left;
  update public.public_profiles set rank_points = right_next,
    battle_wins = battle_wins + (outcome = 'right')::integer - (battle.result = 'right')::integer,
    battle_losses = battle_losses + (outcome = 'left')::integer - (battle.result = 'left')::integer,
    battle_draws = battle_draws + (outcome = 'draw')::integer - (battle.result = 'draw')::integer,
    updated_at = now() where id = battle.player_right;
  update public.daily_battles set result = outcome,
    left_points = left_score, right_points = right_score,
    left_greens = left_hits, right_greens = right_hits,
    left_rank_delta = left_next - left_base, right_rank_delta = right_next - right_base
    where id = battle.id;
  return new;
end;
$function$
;

notify pgrst,'reload schema';
commit;
