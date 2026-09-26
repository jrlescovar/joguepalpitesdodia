begin;

-- A finished match always has a winner. If scores and green counts match,
-- the higher account level wins; player ID makes equal levels deterministic.
create or replace function public.battle_winner(
  p_left uuid, p_right uuid,
  p_left_points integer, p_right_points integer,
  p_left_greens integer, p_right_greens integer
)
returns text language plpgsql stable security definer set search_path = public, pg_temp as $$
declare left_level integer; right_level integer; left_id bigint; right_id bigint;
begin
  if p_left_points > p_right_points then return 'left'; end if;
  if p_right_points > p_left_points then return 'right'; end if;
  if p_left_greens < p_right_greens then return 'left'; end if;
  if p_right_greens < p_left_greens then return 'right'; end if;
  select level, player_id into left_level, left_id from public.public_profiles where id = p_left;
  select level, player_id into right_level, right_id from public.public_profiles where id = p_right;
  if left_level is null or right_level is null then raise exception 'Jogador da batalha não encontrado.'; end if;
  if left_level > right_level then return 'left'; end if;
  if right_level > left_level then return 'right'; end if;
  if left_id < right_id then return 'left'; end if;
  return 'right';
end;
$$;

create or replace function public.finalize_daily_battle(p_day date)
returns void language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare battle public.daily_battles; left_score integer; right_score integer; left_hits integer; right_hits integer; outcome text;
begin
  if p_day >= public.battle_today() then return; end if;
  if not exists (select 1 from public.predictions where day_id=p_day) then return; end if;
  if exists (select 1 from public.predictions where day_id=p_day and status<>'settled') then return; end if;
  perform pg_advisory_xact_lock(hashtext('daily-battle-final-' || p_day::text));
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
    outcome := public.battle_winner(battle.player_left,battle.player_right,left_score,right_score,left_hits,right_hits);
    update public.daily_battles set left_points=left_score,right_points=right_score,left_greens=left_hits,right_greens=right_hits,result=outcome,settled_at=now() where id=battle.id;
    update public.public_profiles set
      rank_points=greatest(0,rank_points + case outcome when 'left' then 15 else -15 end),
      battle_wins=battle_wins + (case when outcome='left' then 1 else 0 end),
      battle_losses=battle_losses + (case when outcome='right' then 1 else 0 end),
      updated_at=now()
      where id=battle.player_left;
    update public.public_profiles set
      rank_points=greatest(0,rank_points + case outcome when 'right' then 15 else -15 end),
      battle_wins=battle_wins + (case when outcome='right' then 1 else 0 end),
      battle_losses=battle_losses + (case when outcome='left' then 1 else 0 end),
      updated_at=now()
      where id=battle.player_right;
  end loop;
end;
$$;

-- Admin corrections must apply the same winner rule as normal settlement.
create or replace function public.reconcile_corrected_battle_pick()
returns trigger language plpgsql security definer set search_path = public, auth, pg_temp as $$
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
  if outcome = battle.result then
    update public.daily_battles set left_points = left_score, right_points = right_score,
      left_greens = left_hits, right_greens = right_hits where id = battle.id;
    return new;
  end if;

  select greatest(0, rank_points - battle.left_rank_delta) into left_base
    from public.public_profiles where id = battle.player_left for update;
  select greatest(0, rank_points - battle.right_rank_delta) into right_base
    from public.public_profiles where id = battle.player_right for update;
  left_bonus := case outcome when 'left' then 15 else -15 end;
  right_bonus := case outcome when 'right' then 15 else -15 end;
  left_next := greatest(0, left_base + left_bonus);
  right_next := greatest(0, right_base + right_bonus);

  update public.public_profiles set rank_points = left_next,
    battle_wins = battle_wins + (outcome = 'left')::integer - (battle.result = 'left')::integer,
    battle_losses = battle_losses + (outcome = 'right')::integer - (battle.result = 'right')::integer,
    battle_draws = battle_draws - (battle.result = 'draw')::integer,
    updated_at = now() where id = battle.player_left;
  update public.public_profiles set rank_points = right_next,
    battle_wins = battle_wins + (outcome = 'right')::integer - (battle.result = 'right')::integer,
    battle_losses = battle_losses + (outcome = 'left')::integer - (battle.result = 'left')::integer,
    battle_draws = battle_draws - (battle.result = 'draw')::integer,
    updated_at = now() where id = battle.player_right;
  update public.daily_battles set result = outcome,
    left_points = left_score, right_points = right_score,
    left_greens = left_hits, right_greens = right_hits,
    left_rank_delta = left_next - left_base, right_rank_delta = right_next - right_base
    where id = battle.id;
  return new;
end;
$$;

-- Only public battle totals are exposed; profile rows remain inaccessible directly.
create or replace function public.get_battle_profile_stats(p_profile_id uuid)
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object('wins', battle_wins, 'losses', battle_losses, 'draws', battle_draws)
  from public.public_profiles where id = p_profile_id;
$$;

revoke execute on function public.battle_winner(uuid,uuid,integer,integer,integer,integer) from public, anon, authenticated;
revoke execute on function public.finalize_daily_battle(date) from public, anon, authenticated;
revoke execute on function public.reconcile_corrected_battle_pick() from public, anon, authenticated;
revoke execute on function public.get_battle_profile_stats(uuid) from public, anon, authenticated;
grant execute on function public.get_battle_profile_stats(uuid) to authenticated;

commit;
