begin;

alter table public.daily_battles
  add column if not exists left_rank_delta integer not null default 0,
  add column if not exists right_rank_delta integer not null default 0;

-- Store the rank change actually applied at finalization, including the 0-point floor.
create or replace function public.record_battle_rank_deltas()
returns trigger language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare left_rank integer; right_rank integer; left_bonus integer; right_bonus integer;
begin
  if old.result <> 'open' or new.result = 'open' then return new; end if;
  if new.result = 'no_contest' then
    new.left_rank_delta := 0;
    new.right_rank_delta := 0;
    return new;
  end if;
  select rank_points into left_rank from public.public_profiles where id = new.player_left;
  select rank_points into right_rank from public.public_profiles where id = new.player_right;
  left_bonus := case new.result when 'left' then 15 when 'right' then -15 else -10 end;
  right_bonus := case new.result when 'right' then 15 when 'left' then -15 else -10 end;
  new.left_rank_delta := greatest(0, left_rank + left_bonus) - left_rank;
  new.right_rank_delta := greatest(0, right_rank + right_bonus) - right_rank;
  return new;
end;
$$;
drop trigger if exists battle_record_rank_deltas on public.daily_battles;
create trigger battle_record_rank_deltas before update of result on public.daily_battles
for each row execute function public.record_battle_rank_deltas();

-- A corrected settled pick can change a finished match's score and winner.
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
  outcome := case when left_score > right_score then 'left'
    when right_score > left_score then 'right'
    when left_hits < right_hits then 'left'
    when right_hits < left_hits then 'right' else 'draw' end;
  if outcome = battle.result then
    update public.daily_battles set left_points = left_score, right_points = right_score,
      left_greens = left_hits, right_greens = right_hits where id = battle.id;
    return new;
  end if;

  select greatest(0, rank_points - battle.left_rank_delta) into left_base
    from public.public_profiles where id = battle.player_left for update;
  select greatest(0, rank_points - battle.right_rank_delta) into right_base
    from public.public_profiles where id = battle.player_right for update;
  left_bonus := case outcome when 'left' then 15 when 'right' then -15 else -10 end;
  right_bonus := case outcome when 'right' then 15 when 'left' then -15 else -10 end;
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
$$;
drop trigger if exists battle_corrected_pick on public.picks;
create trigger battle_corrected_pick after update of option_id, status on public.picks
for each row execute function public.reconcile_corrected_battle_pick();
revoke execute on function public.record_battle_rank_deltas() from public, anon, authenticated;
revoke execute on function public.reconcile_corrected_battle_pick() from public, anon, authenticated;
commit;
