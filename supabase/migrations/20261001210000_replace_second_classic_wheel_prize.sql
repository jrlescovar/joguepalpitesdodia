begin;
do $$
begin
 update public.daily_wheel_prizes set kind='empty',label='Sem recompensa'
 where position=5 and kind='classic' and weight=2850;
 if not found then raise exception 'Expected second personalization sector not found'; end if;
end;$$;
notify pgrst,'reload schema';
commit;
