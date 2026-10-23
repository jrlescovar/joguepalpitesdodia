begin;
alter table public.arena_rank_awards drop constraint arena_rank_awards_place_check;
alter table public.arena_rank_awards add constraint arena_rank_awards_place_check check(place between 1 and 10);
alter table public.arena_rank_awards drop constraint arena_rank_awards_rank_points_check;
alter table public.arena_rank_awards add constraint arena_rank_awards_rank_points_check check(rank_points in (10,15,20,30,40,50,75,85,100));
CREATE OR REPLACE FUNCTION public.grant_arena_rank_awards(p_day date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
 perform pg_advisory_xact_lock(hashtext('arena-rank-awards-'||p_day::text));
 if not exists(select 1 from public.arena_rounds where day_id=p_day and status='finished') then return; end if;
 if not exists(
  with ranked as (
   select profile_id,row_number() over(order by points desc,greens desc,level desc,seed)::int place
   from public.arena_entries where day_id=p_day
  ), expected as (
   select profile_id,place,case when p_day>=date '2026-10-14' then (array[100,85,75,50,40,30,20,15,10,10])[place] else case place when 1 then 30 when 2 then 20 else 10 end end rank_points
   from ranked where place<=case when p_day>=date '2026-10-14' then 10 else 3 end
  )
  select 1 from expected e full join (select * from public.arena_rank_awards where day_id=p_day)a using(profile_id)
  where e.place is distinct from a.place or e.rank_points is distinct from a.rank_points
 ) then return; end if;
 with ranked as (
  select profile_id,row_number() over(order by points desc,greens desc,level desc,seed)::int place
  from public.arena_entries where day_id=p_day
 ), expected as (
  select profile_id,place,case when p_day>=date '2026-10-14' then (array[100,85,75,50,40,30,20,15,10,10])[place] else case place when 1 then 30 when 2 then 20 else 10 end end rank_points
  from ranked where place<=case when p_day>=date '2026-10-14' then 10 else 3 end
 ), deltas as (
  select coalesce(e.profile_id,a.profile_id) profile_id,
   coalesce(e.rank_points,0)-coalesce(a.rank_points,0) amount
  from expected e full join (select * from public.arena_rank_awards where day_id=p_day)a using(profile_id)
 )
 update public.public_profiles p set rank_points=greatest(0,p.rank_points+d.amount),updated_at=now()
 from deltas d where p.id=d.profile_id and d.amount<>0;

 -- Delete all obsolete places together so the unique place/profile keys can
 -- safely swap. Retain the original timestamp for unchanged ledger rows.
 with ranked as (
  select profile_id,row_number() over(order by points desc,greens desc,level desc,seed)::int place
  from public.arena_entries where day_id=p_day
 ), expected as materialized (
  select r.profile_id,r.place,case when p_day>=date '2026-10-14' then (array[100,85,75,50,40,30,20,15,10,10])[r.place] else case r.place when 1 then 30 when 2 then 20 else 10 end end rank_points,
   coalesce(a.awarded_at,now()) awarded_at
  from ranked r left join public.arena_rank_awards a
   on a.day_id=p_day and a.profile_id=r.profile_id and a.place=r.place
  where r.place<=case when p_day>=date '2026-10-14' then 10 else 3 end
 ), removed as (
  delete from public.arena_rank_awards where day_id=p_day returning profile_id
 )
 insert into public.arena_rank_awards(day_id,profile_id,place,rank_points,awarded_at)
 select p_day,profile_id,place,rank_points,awarded_at from expected
 cross join (select count(*) from removed) deletion_barrier;
end;
$function$;
commit;
