begin;
-- All automatic draws start at 200, including high-ranked players. This keeps
-- the requested 500-point ceiling instead of the old unlimited 900+ exception.
create or replace function public.battle_compatible(a integer,b integer)
returns boolean language sql immutable as $$
 select abs(a::bigint-b::bigint)<=200;
$$;

do $$
declare definition text; signature text; anchor text;
begin
 foreach signature in array array['public.pair_waiting_daily_battles(date)','public.join_daily_battle_bye(uuid,date)'] loop
  definition:=pg_get_functiondef(signature::regprocedure);
  anchor:='foreach max_gap in array array[200,300,400] loop';
  if position(anchor in definition)=0 or position('daily_battle_opponents_allowed' in definition)=0 then
   raise exception 'Unexpected pairing definition for %',signature;
  end if;
  definition:=replace(definition,anchor,'foreach max_gap in array array[200,300,400,500] loop');
  execute definition;
 end loop;

 -- Reserved pairs use the same maximum, then incompatible reservations return
 -- to the regular draw instead of preventing the whole round from opening.
 definition:=pg_get_functiondef('public.ensure_daily_battle_round(date)'::regprocedure);
 anchor:='select day_id,player_left,player_right from public.daily_battle_reserved_pairings where day_id=p_day and public.daily_battle_opponents_allowed(p_day,player_left,player_right);';
 if position(anchor in definition)=0 then raise exception 'Unexpected reserved draw definition'; end if;
 definition:=replace(definition,anchor,
  'select r.day_id,r.player_left,r.player_right from public.daily_battle_reserved_pairings r join public.public_profiles l on l.id=r.player_left join public.public_profiles q on q.id=r.player_right where r.day_id=p_day and public.daily_battle_opponents_allowed(p_day,r.player_left,r.player_right) and abs(l.rank_points::bigint-q.rank_points::bigint)<=500;');
 execute definition;
end;
$$;
revoke all on function public.ensure_daily_battle_round(date),public.pair_waiting_daily_battles(date),public.join_daily_battle_bye(uuid,date) from public,anon,authenticated;

-- Only fill open vacancies; already paired/settled results are preserved.
select public.pair_waiting_daily_battles(public.battle_today());
select public.pair_waiting_daily_battles(public.battle_today()+1);
notify pgrst,'reload schema';
commit;
