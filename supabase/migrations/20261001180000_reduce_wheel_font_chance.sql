begin;
-- Move five percentage points from fonts to the three empty sectors.
-- Total weight remains 24000; other rewards retain their probabilities.
do $$
begin
 if (select sum(weight) from public.daily_wheel_prizes)<>24000
 or (select count(*) from public.daily_wheel_prizes where kind='empty')<>3
 or (select weight from public.daily_wheel_prizes where kind='font')<>2850 then
  raise exception 'Unexpected wheel weights';
 end if;
 update public.daily_wheel_prizes set weight=1650 where kind='font';
 update public.daily_wheel_prizes set weight=2300 where kind='empty';
end;$$;
notify pgrst,'reload schema';
commit;
