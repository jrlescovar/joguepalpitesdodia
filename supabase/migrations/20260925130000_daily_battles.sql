begin;

alter table public.public_profiles
  add column if not exists battle_wins integer not null default 0 check (battle_wins >= 0),
  add column if not exists battle_losses integer not null default 0 check (battle_losses >= 0),
  add column if not exists battle_draws integer not null default 0 check (battle_draws >= 0),
  add column if not exists battle_off_streak integer not null default 0 check (battle_off_streak >= 0),
  add column if not exists battle_protected boolean not null default false;

create table if not exists public.daily_battle_rounds (
  day_id date primary key,
  created_at timestamptz not null default now()
);

create table if not exists public.daily_battles (
  id bigint generated always as identity primary key,
  day_id date not null references public.daily_battle_rounds(day_id),
  player_left uuid not null references public.public_profiles(id) on delete cascade,
  player_right uuid references public.public_profiles(id) on delete cascade,
  left_points integer not null default 0,
  right_points integer not null default 0,
  left_greens integer not null default 0,
  right_greens integer not null default 0,
  result text not null default 'open' check (result in ('open','left','right','draw','no_contest')),
  settled_at timestamptz,
  unique (day_id, player_left),
  unique (day_id, player_right),
  check (player_left is distinct from player_right),
  check (left_points >= 0 and right_points >= 0 and left_greens >= 0 and right_greens >= 0)
);
create index if not exists daily_battles_right_idx on public.daily_battles(player_right, day_id desc);

alter table public.daily_battle_rounds enable row level security;
alter table public.daily_battles enable row level security;
revoke all on public.daily_battle_rounds, public.daily_battles from public, anon, authenticated;
revoke all on sequence public.daily_battles_id_seq from public, anon, authenticated;

create or replace function public.battle_today()
returns date language sql stable as $$
  select timezone('America/Sao_Paulo', now())::date;
$$;

create or replace function public.battle_compatible(a integer, b integer)
returns boolean language sql immutable as $$
  select (a >= 900 and b >= 900) or abs(a - b) <= 200;
$$;

create or replace function public.refresh_battle_activity(p_day date)
returns void language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  update public.public_profiles p set
    battle_off_streak = greatest(0, p_day - greatest(date '2026-09-25',
      timezone('America/Sao_Paulo', p.created_at)::date,
      coalesce((select max(timezone('America/Sao_Paulo', k.created_at)::date) from public.picks k where k.profile_id=p.id), timezone('America/Sao_Paulo', p.created_at)::date)
    ) - 1),
    battle_protected = (p_day - greatest(date '2026-09-25',
      timezone('America/Sao_Paulo', p.created_at)::date,
      coalesce((select max(timezone('America/Sao_Paulo', k.created_at)::date) from public.picks k where k.profile_id=p.id), timezone('America/Sao_Paulo', p.created_at)::date)
    ) - 1) >= 2;
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
    outcome := case
      when left_score>right_score then 'left'
      when right_score>left_score then 'right'
      when left_hits<right_hits then 'left'
      when right_hits<left_hits then 'right'
      else 'draw' end;
    update public.daily_battles set left_points=left_score,right_points=right_score,left_greens=left_hits,right_greens=right_hits,result=outcome,settled_at=now() where id=battle.id;
    update public.public_profiles set
      rank_points=greatest(0,rank_points + case outcome when 'left' then 15 when 'right' then -15 else -10 end),
      battle_wins=battle_wins + (case when outcome='left' then 1 else 0 end),
      battle_losses=battle_losses + (case when outcome='right' then 1 else 0 end),
      battle_draws=battle_draws + (case when outcome='draw' then 1 else 0 end),
      updated_at=now()
      where id=battle.player_left;
    update public.public_profiles set
      rank_points=greatest(0,rank_points + case outcome when 'right' then 15 when 'left' then -15 else -10 end),
      battle_wins=battle_wins + (case when outcome='right' then 1 else 0 end),
      battle_losses=battle_losses + (case when outcome='left' then 1 else 0 end),
      battle_draws=battle_draws + (case when outcome='draw' then 1 else 0 end),
      updated_at=now()
      where id=battle.player_right;
  end loop;
end;
$$;

create or replace function public.ensure_daily_battle_round(p_day date)
returns void language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare player record; rival record; available uuid[] := '{}'::uuid[]; candidate uuid; i integer;
begin
  if p_day < date '2026-09-26' or p_day > public.battle_today()+1 then return; end if;
  perform pg_advisory_xact_lock(hashtext('daily-battle-round-' || p_day::text));
  if exists (select 1 from public.daily_battle_rounds where day_id=p_day) then return; end if;
  perform public.finalize_daily_battle(p_day-1);
  perform public.refresh_battle_activity(p_day);
  insert into public.daily_battle_rounds(day_id) values(p_day);
  for player in
    select id,rank_points from public.public_profiles
    where not battle_protected and timezone('America/Sao_Paulo',created_at)::date < p_day
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
end;
$$;

create or replace function public.join_daily_battle_bye(p_profile uuid, p_day date)
returns void language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare player public.public_profiles; waiting_id bigint;
begin
  if p_day<public.battle_today() or p_day>public.battle_today()+1 or not exists (select 1 from public.daily_battle_rounds where day_id=p_day) then return; end if;
  perform pg_advisory_xact_lock(hashtext('daily-battle-join-' || p_day::text));
  if exists (select 1 from public.daily_battles where day_id=p_day and (player_left=p_profile or player_right=p_profile)) then return; end if;
  select * into player from public.public_profiles where id=p_profile;
  if not found or player.battle_protected then return; end if;
  select b.id into waiting_id from public.daily_battles b join public.public_profiles p on p.id=b.player_left
    where b.day_id=p_day and b.player_right is null and public.battle_compatible(player.rank_points,p.rank_points)
    order by random() limit 1 for update of b;
  if waiting_id is not null then update public.daily_battles set player_right=p_profile where id=waiting_id; end if;
end;
$$;

create or replace function public.battle_player_joined()
returns trigger language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  perform public.join_daily_battle_bye(new.id,public.battle_today());
  perform public.join_daily_battle_bye(new.id,public.battle_today()+1);
  return new;
end;
$$;
drop trigger if exists battle_new_profile on public.public_profiles;
create trigger battle_new_profile after insert on public.public_profiles for each row execute function public.battle_player_joined();

create or replace function public.battle_pick_activated()
returns trigger language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  update public.public_profiles set battle_off_streak=0,battle_protected=false where id=new.profile_id;
  perform public.join_daily_battle_bye(new.profile_id,public.battle_today());
  perform public.join_daily_battle_bye(new.profile_id,public.battle_today()+1);
  return new;
end;
$$;
drop trigger if exists battle_new_pick on public.picks;
create trigger battle_new_pick after insert on public.picks for each row execute function public.battle_pick_activated();

create or replace function public.battle_prediction_settled()
returns trigger language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  if new.status='settled' and old.status is distinct from new.status then perform public.finalize_daily_battle(new.day_id); end if;
  return new;
end;
$$;
drop trigger if exists battle_prediction_result on public.predictions;
create trigger battle_prediction_result after update of status on public.predictions for each row execute function public.battle_prediction_settled();

create or replace function public.get_my_daily_battle()
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid; today date; shown_day date; battle public.daily_battles; opponent public.public_profiles; mine public.public_profiles; shown boolean; my_points integer; their_points integer; my_greens integer; their_greens integer; choices jsonb;
begin
  target := public.own_profile_id();
  if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
  today := public.battle_today();
  shown_day := greatest(today,date '2026-09-26');
  perform public.ensure_daily_battle_round(shown_day);
  if shown_day=today then perform public.finalize_daily_battle(today-1); end if;
  select * into mine from public.public_profiles where id=target;
  select * into battle from public.daily_battles where day_id=shown_day and (player_left=target or player_right=target) limit 1;
  if not found then
    return jsonb_build_object('dayId',shown_day,'preview',shown_day>today,'protected',mine.battle_protected,'offStreak',mine.battle_off_streak,'wins',mine.battle_wins,'losses',mine.battle_losses,'draws',mine.battle_draws);
  end if;
  if battle.player_right is not null then
    select * into opponent from public.public_profiles where id=case when battle.player_left=target then battle.player_right else battle.player_left end;
  end if;
  shown := shown_day<=today and exists (select 1 from public.predictions where day_id=shown_day and status='settled');
  select coalesce(sum(case when k.status='green' then coalesce((select (o->>'rankPoints')::integer from jsonb_array_elements(g.options) o where o->>'id'=k.option_id),0) else 0 end),0),count(*) filter (where k.status='green')
    into my_points,my_greens from public.picks k join public.predictions g on g.day_id=k.prediction_day and g.slot=k.slot
    where k.profile_id=target and k.prediction_day=shown_day;
  if opponent.id is not null then
    select coalesce(sum(case when k.status='green' then coalesce((select (o->>'rankPoints')::integer from jsonb_array_elements(g.options) o where o->>'id'=k.option_id),0) else 0 end),0),count(*) filter (where k.status='green')
      into their_points,their_greens from public.picks k join public.predictions g on g.day_id=k.prediction_day and g.slot=k.slot
      where k.profile_id=opponent.id and k.prediction_day=shown_day;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('uid',id,'username',username,'avatarColor',avatar_color,'avatarUrl',avatar_url) order by random()),'[]'::jsonb)
    into choices from (select id,username,avatar_color,avatar_url from public.public_profiles where id<>target and id<>coalesce(opponent.id,target) order by random() limit 4) x;
  return jsonb_build_object(
    'dayId',shown_day,'preview',shown_day>today,'protected',mine.battle_protected,'offStreak',mine.battle_off_streak,
    'wins',mine.battle_wins,'losses',mine.battle_losses,'draws',mine.battle_draws,
    'result',battle.result,'myResult',case when battle.result='draw' then 'draw' when battle.result='no_contest' then 'no_contest' when battle.result='open' then 'open' when (battle.result='left' and battle.player_left=target) or (battle.result='right' and battle.player_right=target) then 'win' else 'loss' end,
    'hasOpponent',opponent.id is not null,'scoreVisible',shown,
    'myPoints',case when shown then my_points else null end,'theirPoints',case when shown then their_points else null end,
    'myGreens',my_greens,'theirGreens',their_greens,
    'me',jsonb_build_object('uid',mine.id,'username',mine.username,'avatarColor',mine.avatar_color,'avatarUrl',mine.avatar_url,'passBorderStyle',case when public.box_style_allowed(mine.id,'frame',mine.pass_border_style) then mine.pass_border_style else 'none' end,'passNameStyle',case when public.box_style_allowed(mine.id,'name',mine.pass_name_style) then mine.pass_name_style else 'none' end),
    'opponent',case when opponent.id is null then null else jsonb_build_object('uid',opponent.id,'username',opponent.username,'avatarColor',opponent.avatar_color,'avatarUrl',opponent.avatar_url,'passBorderStyle',case when public.box_style_allowed(opponent.id,'frame',opponent.pass_border_style) then opponent.pass_border_style else 'none' end,'passNameStyle',case when public.box_style_allowed(opponent.id,'name',opponent.pass_name_style) then opponent.pass_name_style else 'none' end) end,
    'reelCandidates',choices
  );
end;
$$;

revoke execute on function public.get_my_daily_battle() from public,anon,authenticated;
grant execute on function public.get_my_daily_battle() to authenticated;
revoke execute on function public.ensure_daily_battle_round(date),public.finalize_daily_battle(date),public.refresh_battle_activity(date),public.join_daily_battle_bye(uuid,date) from public,anon,authenticated;

do $$ begin
  if public.battle_today()<date '2026-09-26' then perform public.ensure_daily_battle_round(date '2026-09-26');
  else perform public.ensure_daily_battle_round(public.battle_today()); end if;
end $$;

notify pgrst,'reload schema';
commit;
