begin;
-- Extend only the Greens page; retain the original top-ten RPC for other callers.
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.get_ranking_top10()'::regprocedure);
 if (length(definition)-length(replace(definition,'limit 10','')))/length('limit 10')<>1 then raise exception 'Unexpected Greens ranking limit';end if;
 definition:=replace(definition,'public.get_ranking_top10()','public.get_ranking_top20()');
 execute replace(definition,'limit 10','limit 20');
 definition:=pg_get_functiondef('public.get_tournament_ranking_page()'::regprocedure);
 if position('public.get_ranking_top10()' in definition)=0 then raise exception 'Unexpected Greens page function';end if;
 execute replace(definition,'public.get_ranking_top10()','public.get_ranking_top20()');
end $$;
revoke all on function public.get_ranking_top20() from public,anon,authenticated;
grant execute on function public.get_ranking_top20() to authenticated;
notify pgrst,'reload schema';
commit;
