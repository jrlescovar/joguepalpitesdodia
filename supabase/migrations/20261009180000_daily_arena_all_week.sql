begin;
-- Daily Arena runs alongside the weekly championship on every day in Brasilia.
-- Keep the top 100 snapshot, current-day guard and existing reward flow.
create or replace function public.ensure_arena_round(p_day date) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 perform pg_advisory_xact_lock(hashtext('arena-round'));
 if p_day<>public.battle_today() then return; end if;
 if exists(select 1 from public.arena_rounds where day_id=p_day) then return; end if;
 insert into public.arena_rounds(day_id) values(p_day);
 insert into public.arena_entries(day_id,profile_id,seed,qualifying_points,level)
 select p_day,id,row_number() over(order by rank_points desc,player_id),rank_points,level
 from public.public_profiles order by rank_points desc,player_id limit 100;
end;$$;
-- Start today's daily competition, with points from real picks already placed.
select public.ensure_arena_round(public.battle_today());
select public.refresh_arena_round(public.battle_today());
notify pgrst,'reload schema';
commit;
select day_id,status,(select count(*) from public.arena_entries where day_id=r.day_id) participants
from public.arena_rounds r where day_id=public.battle_today();
