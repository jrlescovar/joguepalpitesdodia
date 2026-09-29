begin;
create or replace function public.get_admin_picks_for_day(p_profile_id uuid, p_day_id date)
returns jsonb language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode consultar palpites de jogadores.'; end if;
  if not exists (select 1 from public.public_profiles where id = p_profile_id) then raise exception 'Jogador não encontrado.'; end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'dayId', g.day_id, 'slot', g.slot, 'title', g.title,
      'options', g.options, 'winningOptionId', g.winning_option_id,
      'predictionStatus', g.status, 'closesAt', g.closes_at,
      'optionId', k.option_id, 'status', k.status
    ) order by g.slot), '[]'::jsonb)
    from public.predictions g
    left join public.picks k on g.day_id=k.prediction_day and g.slot=k.slot and k.profile_id=p_profile_id
    where g.day_id=p_day_id
  );
end;
$$;


create or replace function public.admin_add_pick(
  p_profile_id uuid, p_day_id date, p_slot smallint, p_option_id text
)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare
  game public.predictions;
  player public.public_profiles;
  pick public.picks;
  next_status text;
  old_points integer := 0;
  new_points integer := 0;
  next_green integer;
  next_red integer;
  next_xp_awarded integer;
  xp_delta integer := 0;
  total_xp bigint;
  next_level integer := 1;
  next_xp integer;
  next_streak integer := 0;
  result_status text;
  base_xp integer;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode corrigir palpites.'; end if;
  if p_profile_id is null or p_day_id is null or p_slot is null or p_option_id is null then
    raise exception 'Selecione jogador, aposta e opção.';
  end if;
  perform pg_advisory_xact_lock(hashtext('daily-battle-final-' || p_day_id::text));
  select * into game from public.predictions where day_id = p_day_id and slot = p_slot for update;
  if not found then raise exception 'Aposta não encontrada.'; end if;
  if game.closes_at > now() or game.status = 'settling' then
    raise exception 'Aguarde a aposta fechar e o resultado terminar de ser processado.';
  end if;
  if not exists (select 1 from jsonb_array_elements(game.options) o where o->>'id' = p_option_id) then
    raise exception 'Opção inválida para esta aposta.';
  end if;
  select * into player from public.public_profiles where id = p_profile_id for update;
  if not found then raise exception 'Jogador não encontrado.'; end if;
  select * into pick from public.picks
    where profile_id = p_profile_id and prediction_day = p_day_id and slot = p_slot for update;
  if found then raise exception 'Este jogador já fez um palpite. Use Corrigir.'; end if;
  insert into public.picks(profile_id,prediction_day,slot,option_id) values(p_profile_id,p_day_id,p_slot,p_option_id);
  pick.option_id := 'none'; pick.status := 'none'; pick.xp_awarded := 0;
  base_xp := public.pass_xp(5,p_profile_id);
  if p_slot=0 and (player.last_played_prediction is null or p_day_id>player.last_played_prediction) then
    update public.public_profiles set daily_streak_current=case when last_played_prediction=p_day_id-1 then daily_streak_current+1 else 1 end,last_played_prediction=p_day_id where id=p_profile_id;
  end if;
  if game.status = 'settled' and (game.winning_option_id is null or pick.status = 'pending') then
    raise exception 'Resultado inconsistente. A correção foi cancelada.';
  end if;

  if game.status <> 'settled' then
    update public.picks set option_id = p_option_id
      where profile_id = p_profile_id and prediction_day = p_day_id and slot = p_slot;
    update public.public_profiles set level=progress[1],xp=progress[2],updated_at=now()
      from (select public.award_xp(player.level,player.xp,base_xp) as progress) awarded where id=p_profile_id;
    insert into public.admin_pick_corrections
      (admin_auth_id, profile_id, prediction_day, slot, old_option_id, new_option_id,
       old_status, new_status, rank_points_delta, xp_delta)
    values (auth.uid(), p_profile_id, p_day_id, p_slot, pick.option_id, p_option_id,
            pick.status, 'pending', 0, base_xp);
    return jsonb_build_object('ok', true, 'status', 'pending', 'rankPointsDelta', 0, 'xpDelta', base_xp);
  end if;

  next_status := case when p_option_id = game.winning_option_id then 'green' else 'red' end;
  next_green := player.green + (case when next_status = 'green' then 1 else 0 end)
    - (case when pick.status = 'green' then 1 else 0 end);
  next_red := player.red + (case when next_status = 'red' then 1 else 0 end)
    - (case when pick.status = 'red' then 1 else 0 end);
  if next_green < 0 or next_red < 0 then raise exception 'Os totais do jogador estão inconsistentes. Revise o perfil antes da correção.'; end if;

  if pick.status = 'green' then
    select coalesce((o->>'rankPoints')::integer, 0) into old_points
      from jsonb_array_elements(game.options) o where o->>'id' = pick.option_id;
  end if;
  if next_status = 'green' then
    select coalesce((o->>'rankPoints')::integer, 0) into new_points
      from jsonb_array_elements(game.options) o where o->>'id' = p_option_id;
  end if;
  next_xp_awarded := case when next_status = 'green'
    then case when pick.status = 'green' then pick.xp_awarded else public.pass_xp(25, p_profile_id) end
    else 0 end;
  xp_delta := base_xp + next_xp_awarded;
  total_xp := greatest(0, public.total_xp(player.level, player.xp) + xp_delta);
  while total_xp >= next_level * 15 loop
    total_xp := total_xp - next_level * 15;
    next_level := next_level + 1;
  end loop;
  next_xp := total_xp::integer;

  update public.picks set option_id = p_option_id, status = next_status,
    xp_awarded = next_xp_awarded, settled_at=game.settled_at where profile_id = p_profile_id and prediction_day = p_day_id and slot = p_slot;

  -- The current green sequence follows settlement order, not the correction time.
  for result_status in
    select status from public.picks where profile_id = p_profile_id and status <> 'pending'
      order by settled_at desc nulls last, prediction_day desc, slot desc
  loop
    exit when result_status = 'red';
    next_streak := next_streak + 1;
  end loop;
  next_streak := least(next_streak, next_green);

  update public.public_profiles set
    level = next_level, xp = next_xp,
    rank_points = greatest(0, rank_points + new_points - old_points),
    green = next_green, red = next_red,
    green_streak_current = next_streak,
    green_streak_max = least(next_green, greatest(green_streak_max, next_streak)),
    updated_at = now()
  where id = p_profile_id;

  with ranked as (
    select id, row_number() over (order by green desc, public.total_xp(level, xp) desc, player_id asc)::integer as new_position
    from public.public_profiles
  )
  update public.public_profiles p set
    rank_change = coalesce(p.rank_position, r.new_position) - r.new_position,
    rank_position = r.new_position, updated_at = now()
  from ranked r where p.id = r.id;

  insert into public.admin_pick_corrections
    (admin_auth_id, profile_id, prediction_day, slot, old_option_id, new_option_id,
     old_status, new_status, rank_points_delta, xp_delta)
  values (auth.uid(), p_profile_id, p_day_id, p_slot, pick.option_id, p_option_id,
          pick.status, next_status, new_points - old_points, xp_delta);
  return jsonb_build_object('ok', true, 'status', next_status,
    'rankPointsDelta', new_points - old_points, 'xpDelta', xp_delta);
end;
$$;


revoke all on function public.admin_add_pick(uuid,date,smallint,text) from public,anon,authenticated;
grant execute on function public.admin_add_pick(uuid,date,smallint,text) to authenticated;
notify pgrst,'reload schema';
commit;
