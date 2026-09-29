begin;

-- Keep completed rounds so their champions remain visible in Arena history.
create or replace function public.ensure_arena_round(p_day date) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 perform pg_advisory_xact_lock(hashtext('arena-round'));
 if p_day<>public.battle_today() then return; end if;
 if exists(select 1 from public.arena_rounds where day_id=p_day) then return; end if;
 insert into public.arena_rounds(day_id) values(p_day);
 insert into public.arena_entries(day_id,profile_id,seed,qualifying_points)
 select p_day,id,row_number() over(order by rank_points desc,player_id),rank_points
 from public.public_profiles order by rank_points desc,player_id limit 10;
end;$$;

create function public.get_arena_history(p_before_day date default null) returns jsonb
language plpgsql stable security definer set search_path=public,auth,pg_temp as $$
declare payload jsonb;
begin
 if auth.uid() is null then raise exception 'Entre para visualizar o Histórico da Arena.'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'dayId',past.day_id,
   'winner',public.get_public_profile(past.winner_id),
   'points',past.points,
   'greens',past.greens
 ) order by past.day_id desc),'[]'::jsonb) into payload
 from (
  select r.day_id,r.winner_id,e.points,e.greens
  from public.arena_rounds r
  join public.arena_entries e on e.day_id=r.day_id and e.profile_id=r.winner_id
  where r.status='finished' and r.winner_id is not null
    and (p_before_day is null or r.day_id<p_before_day)
  order by r.day_id desc limit 11
 ) past;
 return payload;
end;$$;

revoke all on function public.get_arena_history(date) from public,anon,authenticated;
grant execute on function public.get_arena_history(date) to authenticated;

commit;
