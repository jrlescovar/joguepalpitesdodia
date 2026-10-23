begin;
-- Seed is the unique global PontosRank position captured at arena opening.
-- Keep the old order for completed dates before this rule's introduction.
do $$
declare definition text; revised text; old_order text; new_order text;
begin
 old_order:='order by points desc,greens desc,level desc,seed';
 new_order:='order by points desc,case when p_day>=date ''2026-10-17'' then seed end,greens desc,level desc,seed';
 definition:=pg_get_functiondef('public.arena_winner(date)'::regprocedure);
 revised:=replace(definition,old_order,new_order);
 if revised=definition then raise exception 'Unexpected daily arena winner ordering';end if;
 execute revised;

 definition:=pg_get_functiondef('public.grant_arena_rank_awards(date)'::regprocedure);
 if (length(definition)-length(replace(definition,old_order,'')))/length(old_order)<>3 then
  raise exception 'Unexpected arena reward ordering';
 end if;
 execute replace(definition,old_order,new_order);

 definition:=pg_get_functiondef('public.get_arena()'::regprocedure);
 old_order:='order by points desc,greens desc,e.level desc,seed';
 new_order:='order by points desc,case when e.day_id>=date ''2026-10-17'' then e.seed end,greens desc,e.level desc,seed';
 revised:=replace(definition,old_order,new_order);
 if revised=definition then raise exception 'Unexpected daily arena display ordering';end if;
 old_order:='order by a.points desc,a.greens desc,a.level desc,a.seed,p.player_id';
 new_order:='order by a.points desc,case when a.day_id>=date ''2026-10-17'' then a.seed end,a.greens desc,a.level desc,a.seed,p.player_id';
 definition:=replace(revised,old_order,new_order);
 if definition=revised then raise exception 'Unexpected daily winner ordering in week view';end if;
 execute definition;
end $$;
notify pgrst,'reload schema';
commit;
