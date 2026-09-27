begin;

create or replace function public.finalize_daily_battle(p_day date)
returns void language plpgsql security definer set search_path = public, auth, pg_temp as $$
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

create or replace function public.settle_prediction_for_slot(p_day_id date,p_slot smallint,p_winning_option_id text)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare game public.predictions;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode concluir desafios.'; end if;
  perform pg_advisory_xact_lock(hashtext('daily-battle-final-' || p_day_id::text));
  select * into game from public.predictions where day_id=p_day_id and slot=p_slot for update;
  if not found then raise exception 'Desafio não encontrado.'; end if;
  if game.status='settled' then
    if game.winning_option_id<>p_winning_option_id then raise exception 'O resultado já foi confirmado e não pode mudar.'; end if;
    return jsonb_build_object('ok',true);
  end if;
  if game.closes_at>now() then raise exception 'Aguarde o prazo terminar.'; end if;
  if not exists(select 1 from jsonb_array_elements(game.options) option where option->>'id'=p_winning_option_id) then raise exception 'Resultado inválido.'; end if;
  update public.predictions set status='settling',winning_option_id=p_winning_option_id,updated_at=now() where day_id=p_day_id and slot=p_slot;
  with results as (
    select p.id,k.option_id=p_winning_option_id as won,
      coalesce((select (o->>'rankPoints')::integer from jsonb_array_elements(game.options) o where o->>'id'=k.option_id),0) as awarded_rank_points,
      public.award_xp(p.level,p.xp,case when k.option_id=p_winning_option_id then public.pass_xp(25,p.id) else 0 end) as progress
    from public.public_profiles p join public.picks k on k.profile_id=p.id
    where k.prediction_day=p_day_id and k.slot=p_slot and k.status='pending'
  )
  update public.public_profiles p set
    level=r.progress[1],xp=r.progress[2],rank_points=p.rank_points+(case when r.won then r.awarded_rank_points else 0 end),green=p.green+(case when r.won then 1 else 0 end),red=p.red+(case when r.won then 0 else 1 end),
    green_streak_current=case when r.won then p.green_streak_current+1 else 0 end,
    green_streak_max=case when r.won then greatest(p.green_streak_max,p.green_streak_current+1) else p.green_streak_max end,
    last_settled_prediction=p_day_id,updated_at=now()
  from results r where p.id=r.id;
  update public.picks set status=case when option_id=p_winning_option_id then 'green' else 'red' end,xp_awarded=case when option_id=p_winning_option_id then public.pass_xp(25,profile_id) else 0 end,settled_at=now() where prediction_day=p_day_id and slot=p_slot and status='pending';
  with ranked as (select id,row_number() over(order by green desc,public.total_xp(level,xp) desc,player_id asc)::integer as new_position from public.public_profiles)
  update public.public_profiles p set rank_change=coalesce(p.rank_position,r.new_position)-r.new_position,rank_position=r.new_position,updated_at=now() from ranked r where p.id=r.id;
  update public.predictions set status='settled',settled_at=now(),updated_at=now() where day_id=p_day_id and slot=p_slot;
  return jsonb_build_object('ok',true);
end;
$$;

-- Once the last published game is settled, this round is closed.
-- Publication and settlement share the lock so a concurrent new game cannot be missed.
create or replace function public.guard_finished_battle_day()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform pg_advisory_xact_lock(hashtext('daily-battle-final-' || new.day_id::text));
  if exists (select 1 from public.daily_battles where day_id=new.day_id and result<>'open') then
    raise exception 'A Batalha do Dia já foi encerrada. Publique o novo desafio em outra data.';
  end if;
  return new;
end;
$$;
create trigger guard_finished_battle_day before insert on public.predictions
for each row execute function public.guard_finished_battle_day();

create or replace function public.get_my_daily_battle_with_ranks()
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare payload jsonb; battle public.daily_battles; target uuid;
begin
  payload := public.get_my_daily_battle();
  target := public.own_profile_id();
  if jsonb_typeof(payload->'me') = 'object' then
    payload := jsonb_set(payload, '{me}', payload->'me' || public.battle_rank_meta((payload#>>'{me,uid}')::uuid));
  end if;
  if jsonb_typeof(payload->'opponent') = 'object' then
    payload := jsonb_set(payload, '{opponent}', payload->'opponent' || public.battle_rank_meta((payload#>>'{opponent,uid}')::uuid));
  end if;
  select * into battle from public.daily_battles
    where day_id=(payload->>'dayId')::date and (player_left=target or player_right=target);
  return payload || jsonb_build_object('myRankDelta', case
    when battle.result in ('left','right','draw','no_contest') then
      case when battle.player_left=target then battle.left_rank_delta else battle.right_rank_delta end
    else null end);
end;
$$;

revoke execute on function public.finalize_daily_battle(date), public.guard_finished_battle_day() from public, anon, authenticated;
revoke execute on function public.settle_prediction_for_slot(date,smallint,text), public.get_my_daily_battle_with_ranks() from public, anon, authenticated;
grant execute on function public.settle_prediction_for_slot(date,smallint,text), public.get_my_daily_battle_with_ranks() to authenticated;

-- Close today's round if its last result was already confirmed before this update.
select public.finalize_daily_battle(public.battle_today());
notify pgrst, 'reload schema';

commit;
