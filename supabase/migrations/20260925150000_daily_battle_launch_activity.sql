-- Do not count inactivity from before the launch of daily battles.
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

select public.refresh_battle_activity(date '2026-09-26');

-- Include accounts excluded from the launch preview by the old streak count.
do $$
declare unmatched uuid[];
begin
  select array_agg(p.id order by p.id) into unmatched from public.public_profiles p
  where not exists (
    select 1 from public.daily_battles b
    where b.day_id=date '2026-09-26' and p.id in (b.player_left,b.player_right)
  );
  if array_length(unmatched,1)=2 and public.battle_compatible(
    (select rank_points from public.public_profiles where id=unmatched[1]),
    (select rank_points from public.public_profiles where id=unmatched[2])
  ) then
    insert into public.daily_battles(day_id,player_left,player_right)
    values(date '2026-09-26',unmatched[1],unmatched[2]);
  end if;
end;
$$;
