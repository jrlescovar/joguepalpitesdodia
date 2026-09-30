begin;

-- Keep the original 200-point draw. Only its open, unpaired entries can be
-- combined in successive passes, using the points captured at the draw.
create function public.pair_waiting_daily_battles(p_day date)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare max_gap integer; pairing record;
begin
  if p_day < public.battle_today() or p_day > public.battle_today()+1 then return; end if;
  perform pg_advisory_xact_lock(hashtext('daily-battle-round-' || p_day::text));
  perform pg_advisory_xact_lock(hashtext('daily-battle-final-' || p_day::text));
  if exists(select 1 from public.predictions where day_id=p_day)
    and not exists(select 1 from public.predictions where day_id=p_day and status<>'settled') then return; end if;
  foreach max_gap in array array[200,300,400] loop
    loop
      select l.id as left_battle,r.id as right_battle,r.player_left as rival,
        coalesce(r.left_start_rank_points,rp.rank_points) as rival_start
      into pairing
      from public.daily_battles l join public.daily_battles r on r.day_id=l.day_id and l.id<r.id
      join public.public_profiles lp on lp.id=l.player_left
      join public.public_profiles rp on rp.id=r.player_left
      where l.day_id=p_day and l.result='open' and r.result='open'
        and l.player_right is null and r.player_right is null
        and ((max_gap=200 and public.battle_compatible(coalesce(l.left_start_rank_points,lp.rank_points),coalesce(r.left_start_rank_points,rp.rank_points)))
          or abs(coalesce(l.left_start_rank_points,lp.rank_points)-coalesce(r.left_start_rank_points,rp.rank_points))<=max_gap)
      order by random() limit 1 for update of l,r;
      exit when not found;
      delete from public.daily_battles where id=pairing.right_battle;
      update public.daily_battles set player_right=pairing.rival,right_start_rank_points=pairing.rival_start
        where id=pairing.left_battle;
    end loop;
  end loop;
end;
$$;
revoke all on function public.pair_waiting_daily_battles(date) from public,anon,authenticated;

create or replace function public.ensure_daily_battle_round(p_day date)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare player record; rival record; available uuid[] := '{}'::uuid[]; candidate uuid; i integer;
begin
  if p_day < date '2026-09-26' or p_day > public.battle_today()+1 then return; end if;
  perform pg_advisory_xact_lock(hashtext('daily-battle-round-' || p_day::text));
  if exists(select 1 from public.daily_battle_rounds where day_id=p_day) then
    perform public.pair_waiting_daily_battles(p_day);
    return;
  end if;
  perform public.finalize_daily_battle(p_day-1);
  perform public.refresh_battle_activity(p_day);
  insert into public.daily_battle_rounds(day_id) values(p_day);
  insert into public.daily_battles(day_id,player_left,player_right)
    select day_id,player_left,player_right from public.daily_battle_reserved_pairings where day_id=p_day;
  for player in
    select p.id,p.rank_points from public.public_profiles p
    where not p.battle_protected and timezone('America/Sao_Paulo',p.created_at)::date < p_day
      and not exists(select 1 from public.daily_battles b where b.day_id=p_day and (b.player_left=p.id or b.player_right=p.id))
    order by random()
  loop
    candidate := null;
    for rival in
      select p.id,p.rank_points from public.public_profiles p
      where p.id=any(available) and public.battle_compatible(player.rank_points,p.rank_points)
      order by random() limit 1
    loop candidate := rival.id; end loop;
    if candidate is null then
      available := array_append(available,player.id);
    else
      insert into public.daily_battles(day_id,player_left,player_right) values(p_day,candidate,player.id);
      available := array_remove(available,candidate);
    end if;
  end loop;
  for i in 1..coalesce(array_length(available,1),0) loop
    insert into public.daily_battles(day_id,player_left) values(p_day,available[i]);
  end loop;
  perform public.pair_waiting_daily_battles(p_day);
end;
$$;
revoke all on function public.ensure_daily_battle_round(date) from public,anon,authenticated;

create or replace function public.join_daily_battle_bye(p_profile uuid,p_day date)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare player public.public_profiles; waiting_id bigint; max_gap integer;
begin
  if p_day<public.battle_today() or p_day>public.battle_today()+1 then return; end if;
  perform pg_advisory_xact_lock(hashtext('daily-battle-round-' || p_day::text));
  perform pg_advisory_xact_lock(hashtext('daily-battle-final-' || p_day::text));
  if not exists(select 1 from public.daily_battle_rounds where day_id=p_day) then return; end if;
  if exists(select 1 from public.predictions where day_id=p_day)
    and not exists(select 1 from public.predictions where day_id=p_day and status<>'settled') then return; end if;
  if exists(select 1 from public.daily_battles where day_id=p_day and (player_left=p_profile or player_right=p_profile)) then return; end if;
  select * into player from public.public_profiles where id=p_profile;
  if not found or player.battle_protected then return; end if;
  foreach max_gap in array array[200,300,400] loop
    select b.id into waiting_id from public.daily_battles b join public.public_profiles p on p.id=b.player_left
      where b.day_id=p_day and b.result='open' and b.player_right is null
        and ((max_gap=200 and public.battle_compatible(player.rank_points,coalesce(b.left_start_rank_points,p.rank_points)))
          or abs(player.rank_points-coalesce(b.left_start_rank_points,p.rank_points))<=max_gap)
      order by random() limit 1 for update of b;
    if waiting_id is not null then
      update public.daily_battles set player_right=p_profile where id=waiting_id;
      exit;
    end if;
  end loop;
end;
$$;
revoke all on function public.join_daily_battle_bye(uuid,date) from public,anon,authenticated;

-- Backfill only live vacancies, without redrawing paired or settled battles.
select public.pair_waiting_daily_battles(public.battle_today());
select public.pair_waiting_daily_battles(public.battle_today()+1);
notify pgrst,'reload schema';
commit;
