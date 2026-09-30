begin;

-- A SQL fixture left battle_today() on 2070-01-01. Restore the three
-- accidental Arena awards before removing that artificial day.
do $$
begin
  if (select count(*) from public.arena_rank_awards where day_id = date '2070-01-01') <> 3 then
    raise exception 'Unexpected future Arena awards; inspect before cleanup';
  end if;
  if (select count(*) from public.predictions where day_id = date '2070-01-01'
      and title in ('Teste resultado principal', 'Teste ultimo resultado')) <> 2 then
    raise exception 'Unexpected future predictions; inspect before cleanup';
  end if;
end;
$$;

update public.public_profiles p
set rank_points = p.rank_points - a.rank_points
from public.arena_rank_awards a
where a.day_id = date '2070-01-01' and a.profile_id = p.id;

update public.public_profiles
set arena_wins = arena_wins - 1
where id = (select winner_id from public.arena_rounds where day_id = date '2070-01-01');

update public.arena_crown c
set profile_id = r.winner_id, won_on = r.day_id
from public.arena_rounds r
where c.won_on = date '2070-01-01' and r.day_id = date '2026-09-29';

delete from public.arena_rank_awards where day_id = date '2070-01-01';
delete from public.arena_rounds where day_id = date '2070-01-01';
delete from public.daily_battles where day_id = date '2070-01-01';
delete from public.picks where prediction_day = date '2070-01-01';
delete from public.predictions where day_id = date '2070-01-01';
delete from public.daily_battle_rounds where day_id = date '2070-01-01';
delete from public.public_profiles where player_id between 99000001 and 99000005
  and username in ('btstwin','btstloss','btstfloor','btstother','btstbye');

commit;
