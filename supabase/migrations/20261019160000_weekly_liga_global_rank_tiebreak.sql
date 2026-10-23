begin;
-- Use the same current global PontosRank position shown on public profiles.
-- Weekly points still decide first; greens follow the global position.
-- Completed championships before the Liga phase remain untouched.
do $$
declare definition text; old_order text; new_order text; target regprocedure;
begin
 old_order:='order by sum(s.points) desc,sum(s.greens) desc,max(s.level) desc,p.player_id';
 new_order:='order by sum(s.points) desc,min((public.battle_rank_meta(s.profile_id)->>''globalPosition'')::bigint),sum(s.greens) desc,p.player_id';
 foreach target in array array['public.refresh_weekly_arena()'::regprocedure,'public.get_arena()'::regprocedure] loop
  definition:=pg_get_functiondef(target);
  if (length(definition)-length(replace(definition,old_order,'')))/length(old_order)<>1 then
   raise exception 'Unexpected weekly ordering in %',target;
  end if;
  execute replace(definition,old_order,new_order);
 end loop;
end $$;
notify pgrst,'reload schema';
commit;
