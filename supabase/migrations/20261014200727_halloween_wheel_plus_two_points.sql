begin;
-- Transfer 2 percentage points (480/24000) from empty to Halloween.
-- Existing Thursday-only supporter eligibility and every other prize stay unchanged.
do $$begin
 if (select sum(weight) from public.daily_wheel_prizes)<>24000
 or (select weight from public.daily_wheel_prizes where kind='halloween')<>1890
 or (select count(*) from public.daily_wheel_prizes where kind='empty')<>5
 or (select sum(weight) from public.daily_wheel_prizes where kind='empty')<>10230 then
  raise exception 'Unexpected wheel weights; review before applying';
 end if;
 update public.daily_wheel_prizes set weight=weight+480 where kind='halloween';
 update public.daily_wheel_prizes set weight=weight-96 where kind='empty';
end $$;
commit;
