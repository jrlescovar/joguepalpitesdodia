begin;
-- Keep the existing history array and cursor contract; include its unfiltered total.
CREATE OR REPLACE FUNCTION public.get_arena_history(p_before_day date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare payload jsonb; total_entries bigint;
begin
 if auth.uid() is null then raise exception 'Entre para visualizar o Histórico da Arena.'; end if;
 select count(*) into total_entries from public.arena_rounds r
 join public.arena_entries e on e.day_id=r.day_id and e.profile_id=r.winner_id
 where r.status='finished' and r.winner_id is not null;
 select coalesce(jsonb_agg(jsonb_build_object(
   'dayId',past.day_id,
   'winner',public.get_public_profile(past.winner_id),
   'points',past.points,
   'greens',past.greens,
   'totalEntries',total_entries
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
end;$function$
;
notify pgrst,'reload schema';
commit;
