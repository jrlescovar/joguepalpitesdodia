begin;
-- Transfer four percentage points from Halloween to the four empty sectors.
-- Total weight stays 24000; all other prizes keep their current chances.
do $$
begin
 if (select sum(weight) from public.daily_wheel_prizes)<>24000
 or (select count(*) from public.daily_wheel_prizes where kind='empty')<>4
 or (select sum(weight) from public.daily_wheel_prizes where kind='empty')<>6420
 or (select weight from public.daily_wheel_prizes where kind='halloween')<>2850 then
  raise exception 'Unexpected wheel weights';
 end if;
 update public.daily_wheel_prizes set weight=1890 where kind='halloween';
 update public.daily_wheel_prizes set weight=1845 where kind='empty';
end;$$;
notify pgrst,'reload schema';
commit;
