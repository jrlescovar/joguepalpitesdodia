begin;

-- An owner-requested pairing applies only to its exact date. All other players
-- keep the usual random matching and compatibility rules.
create table public.daily_battle_reserved_pairings (
  day_id date primary key,
  player_left uuid not null references public.public_profiles(id) on delete cascade,
  player_right uuid not null references public.public_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (player_left <> player_right)
);
alter table public.daily_battle_reserved_pairings enable row level security;
revoke all on public.daily_battle_reserved_pairings from public, anon, authenticated;

-- Historical player-specific reservations are omitted from the public source.

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
  insert into public.daily_battles(day_id,player_left,player_right)
    select day_id,player_left,player_right from public.daily_battle_reserved_pairings where day_id=p_day;
  for player in
    select p.id,p.rank_points from public.public_profiles p
    where not p.battle_protected and timezone('America/Sao_Paulo',p.created_at)::date < p_day
      and not exists (select 1 from public.daily_battles b where b.day_id=p_day and (b.player_left=p.id or b.player_right=p.id))
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
revoke execute on function public.ensure_daily_battle_round(date) from public, anon, authenticated;
commit;
