begin;
do $$ declare definition text; begin
 definition:=pg_get_functiondef('public.get_arena()'::regprocedure);
 definition:=regexp_replace(definition,'public.get_public_profile\((profile_id|home_id|away_id)\)','(public.get_public_profile(\1)||public.battle_rank_meta(\1))','g');
 execute definition;
end $$;
notify pgrst,'reload schema';
commit;
select pg_get_functiondef('public.get_arena()'::regprocedure) like '%public.battle_rank_meta(home_id)%' as home_global_rank,pg_get_functiondef('public.get_arena()'::regprocedure) like '%public.battle_rank_meta(away_id)%' as away_global_rank;
