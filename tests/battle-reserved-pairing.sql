-- Run with the reservation migration inside one transaction, then ROLLBACK.
do $$
declare first_round jsonb; next_round jsonb; eligible integer; enrolled integer;
begin
  perform public.ensure_daily_battle_round(date '2026-09-27');
  if not exists (
    select 1 from public.daily_battles b
    join public.public_profiles l on l.id=b.player_left
    join public.public_profiles r on r.id=b.player_right
    where b.day_id=date '2026-09-27' and l.username='cadu' and r.username='santosgoat' and b.result='open'
  ) then raise exception 'Requested pairing missing'; end if;
  if exists (
    select id from (
      select player_left id from public.daily_battles where day_id=date '2026-09-27'
      union all select player_right from public.daily_battles where day_id=date '2026-09-27' and player_right is not null
    ) entries group by id having count(*)>1
  ) then raise exception 'Player entered more than once'; end if;
  select count(*) into eligible from public.public_profiles
    where not battle_protected and timezone('America/Sao_Paulo',created_at)::date < date '2026-09-27';
  select sum(case when player_right is null then 1 else 2 end) into enrolled
    from public.daily_battles where day_id=date '2026-09-27';
  if eligible<>enrolled then raise exception 'Eligible players missing: % vs %',eligible,enrolled; end if;
  if exists (
    select 1 from public.daily_battles b
    join public.public_profiles l on l.id=b.player_left
    join public.public_profiles r on r.id=b.player_right
    where b.day_id=date '2026-09-27' and not public.battle_compatible(l.rank_points,r.rank_points)
  ) then raise exception 'Compatibility changed'; end if;
  select jsonb_agg(to_jsonb(b) order by id) into first_round from public.daily_battles b where day_id=date '2026-09-27';
  perform public.ensure_daily_battle_round(date '2026-09-27');
  select jsonb_agg(to_jsonb(b) order by id) into next_round from public.daily_battles b where day_id=date '2026-09-27';
  if first_round is distinct from next_round then raise exception 'Repeated call changed the draw'; end if;
  if has_table_privilege('authenticated','public.daily_battle_reserved_pairings','INSERT')
     or has_table_privilege('anon','public.daily_battle_reserved_pairings','SELECT') then raise exception 'Reservation table exposed'; end if;
end;
$$;
