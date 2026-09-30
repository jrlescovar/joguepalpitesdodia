begin;
do $$ declare item record; definition text; begin
 for item in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' and p.prosrc ilike '%batalha%' loop
  definition:=pg_get_functiondef(item.oid);
  definition:=replace(definition,'A Batalha do Dia já foi encerrada','O Confronto do Dia já foi encerrado');
  definition:=replace(definition,'da batalha','do confronto');
  execute definition;
 end loop;
end; $$;
notify pgrst,'reload schema';
commit;
