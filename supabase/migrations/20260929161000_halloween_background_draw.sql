begin;
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.open_halloween_box(uuid)'::regprocedure);
 if position('(''name''),(''frame''),(''font'')' in definition)=0 then raise exception 'Unexpected Halloween catalog query'; end if;
 execute replace(definition,'(''name''),(''frame''),(''font'')','(''name''),(''frame''),(''font''),(''background'')');
end;$$;
notify pgrst, 'reload schema';
commit;
