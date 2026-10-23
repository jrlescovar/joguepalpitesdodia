begin;
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.get_arena()'::regprocedure);
 if position('''startsOn'',w,''settled''' in definition)=0 then
  definition:=replace(definition,'''startsOn'',w,''status'',s.status','''startsOn'',w,''settled'',(select count(*) from public.predictions where day_id between w and w+6 and status=''settled''),''status'',s.status');
  execute definition;
 end if;
end;$$;
notify pgrst,'reload schema';
commit;
