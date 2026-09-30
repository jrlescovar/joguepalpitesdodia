begin;

-- Capture each fighter's rank when the matchup is formed. Old completed
-- battles intentionally keep NULL snapshots and retain their original rules.
alter table public.daily_battles
  add column left_start_rank_points integer,
  add column right_start_rank_points integer;

create function public.capture_battle_start_ranks() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if new.left_start_rank_points is null then
    select rank_points into new.left_start_rank_points from public.public_profiles where id=new.player_left;
  end if;
  if new.player_right is not null and new.right_start_rank_points is null then
    select rank_points into new.right_start_rank_points from public.public_profiles where id=new.player_right;
  end if;
  return new;
end;$$;
create trigger capture_battle_start_ranks
before insert or update of player_right on public.daily_battles
for each row execute function public.capture_battle_start_ranks();
revoke all on function public.capture_battle_start_ranks() from public,anon,authenticated;

-- These boundaries match src/rankTiers.ts. A win over a higher patent is
-- worth 25; all other decided battles remain worth 15.
create function public.battle_rank_tier(p_points integer) returns integer
language sql immutable security definer set search_path=public,pg_temp as $$
  select case when p_points >= 2100 then 10 when p_points >= 1801 then 9
    when p_points >= 1501 then 8 when p_points >= 1201 then 7
    when p_points >= 901 then 6 when p_points >= 601 then 5
    when p_points >= 401 then 4 when p_points >= 251 then 3
    when p_points >= 100 then 2 else 1 end;
$$;
revoke all on function public.battle_rank_tier(integer) from public,anon,authenticated;

create function public.battle_win_bonus(p_left_start integer,p_right_start integer,p_outcome text)
returns integer language sql immutable security definer set search_path=public,pg_temp as $$
  select case when p_outcome='draw' then 0
    when p_left_start is null or p_right_start is null then 15
    when p_outcome='left' and public.battle_rank_tier(p_left_start)<public.battle_rank_tier(p_right_start) then 25
    when p_outcome='right' and public.battle_rank_tier(p_right_start)<public.battle_rank_tier(p_left_start) then 25
    else 15 end;
$$;
revoke all on function public.battle_win_bonus(integer,integer,text) from public,anon,authenticated;

-- Apply the same award in final settlement, displayed deltas and admin
-- corrections. The guards prevent silently patching an unexpected version.
do $$
declare definition text; changed text;
begin
  definition:=pg_get_functiondef('public.finalize_daily_battle(date)'::regprocedure);
  if position('case outcome when ''left'' then 15 when ''right'' then -15 else 0 end' in definition)=0
    or position('case outcome when ''right'' then 15 when ''left'' then -15 else 0 end' in definition)=0 then
    raise exception 'Unexpected battle finalization definition';
  end if;
  changed:=replace(definition,
    'case outcome when ''left'' then 15 when ''right'' then -15 else 0 end',
    'case outcome when ''left'' then public.battle_win_bonus(battle.left_start_rank_points,battle.right_start_rank_points,outcome) when ''right'' then -public.battle_win_bonus(battle.left_start_rank_points,battle.right_start_rank_points,outcome) else 0 end');
  changed:=replace(changed,
    'case outcome when ''right'' then 15 when ''left'' then -15 else 0 end',
    'case outcome when ''right'' then public.battle_win_bonus(battle.left_start_rank_points,battle.right_start_rank_points,outcome) when ''left'' then -public.battle_win_bonus(battle.left_start_rank_points,battle.right_start_rank_points,outcome) else 0 end');
  execute changed;

  definition:=pg_get_functiondef('public.record_battle_rank_deltas()'::regprocedure);
  if position('case new.result when ''left'' then 15 when ''right'' then -15 else 0 end' in definition)=0
    or position('case new.result when ''right'' then 15 when ''left'' then -15 else 0 end' in definition)=0 then
    raise exception 'Unexpected battle delta definition';
  end if;
  changed:=replace(definition,
    'case new.result when ''left'' then 15 when ''right'' then -15 else 0 end',
    'case new.result when ''left'' then public.battle_win_bonus(new.left_start_rank_points,new.right_start_rank_points,new.result) when ''right'' then -public.battle_win_bonus(new.left_start_rank_points,new.right_start_rank_points,new.result) else 0 end');
  changed:=replace(changed,
    'case new.result when ''right'' then 15 when ''left'' then -15 else 0 end',
    'case new.result when ''right'' then public.battle_win_bonus(new.left_start_rank_points,new.right_start_rank_points,new.result) when ''left'' then -public.battle_win_bonus(new.left_start_rank_points,new.right_start_rank_points,new.result) else 0 end');
  execute changed;

  definition:=pg_get_functiondef('public.reconcile_corrected_battle_pick()'::regprocedure);
  if position('left_bonus := case outcome when ''left'' then 15 when ''right'' then -15 else 0 end;' in definition)=0
    or position('right_bonus := case outcome when ''right'' then 15 when ''left'' then -15 else 0 end;' in definition)=0 then
    raise exception 'Unexpected battle correction definition';
  end if;
  changed:=replace(definition,
    'left_bonus := case outcome when ''left'' then 15 when ''right'' then -15 else 0 end;',
    'left_bonus := case outcome when ''left'' then public.battle_win_bonus(battle.left_start_rank_points,battle.right_start_rank_points,outcome) when ''right'' then -public.battle_win_bonus(battle.left_start_rank_points,battle.right_start_rank_points,outcome) else 0 end;');
  changed:=replace(changed,
    'right_bonus := case outcome when ''right'' then 15 when ''left'' then -15 else 0 end;',
    'right_bonus := case outcome when ''right'' then public.battle_win_bonus(battle.left_start_rank_points,battle.right_start_rank_points,outcome) when ''left'' then -public.battle_win_bonus(battle.left_start_rank_points,battle.right_start_rank_points,outcome) else 0 end;');
  execute changed;
end;$$;

-- Each arena prize has a durable, unique record. The ledger also protects
-- the already finished first round from being paid twice.
create table public.arena_rank_awards (
  day_id date not null references public.arena_rounds(day_id),
  profile_id uuid not null references public.public_profiles(id),
  place integer not null check(place between 1 and 3),
  rank_points integer not null check(rank_points in (10,20,30)),
  awarded_at timestamptz not null default now(),
  primary key(day_id,profile_id),
  unique(day_id,place)
);
alter table public.arena_rank_awards enable row level security;
revoke all on public.arena_rank_awards from public,anon,authenticated;

create function public.grant_arena_rank_awards(p_day date) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform pg_advisory_xact_lock(hashtext('arena-rank-awards-'||p_day::text));
  if not exists(select 1 from public.arena_rounds where day_id=p_day and status='finished') then return; end if;
  with ranked as (
    select profile_id,row_number() over(order by points desc,greens desc,level desc,seed) as place
    from public.arena_entries where day_id=p_day
  ), credited as (
    insert into public.arena_rank_awards(day_id,profile_id,place,rank_points)
    select p_day,profile_id,place::integer,case place when 1 then 30 when 2 then 20 else 10 end
    from ranked where place<=3
    on conflict do nothing returning profile_id,rank_points
  )
  update public.public_profiles p set rank_points=p.rank_points+c.rank_points,updated_at=now()
  from credited c where p.id=c.profile_id;
end;$$;
revoke all on function public.grant_arena_rank_awards(date) from public,anon,authenticated;

create function public.grant_finished_arena_rank_awards() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if old.status<>'finished' and new.status='finished' then
    perform public.grant_arena_rank_awards(new.day_id);
  end if;
  return new;
end;$$;
create trigger grant_finished_arena_rank_awards
after update of status on public.arena_rounds
for each row execute function public.grant_finished_arena_rank_awards();
revoke all on function public.grant_finished_arena_rank_awards() from public,anon,authenticated;

-- The inaugural Arena already finished before prize points were introduced.
select public.grant_arena_rank_awards(day_id) from public.arena_rounds where status='finished';

commit;
