begin;
do $$
begin
 if (select sum(weight) from public.daily_wheel_prizes)<>24000
 or (select count(*) from public.daily_wheel_prizes where kind='empty')<>3
 or (select weight from public.daily_wheel_prizes where kind='font')<>1650 then
  raise exception 'Unexpected wheel weights';
 end if;
end;$$;
alter table public.daily_wheel_prizes drop constraint daily_wheel_prizes_position_check;
alter table public.daily_wheel_prizes add constraint daily_wheel_prizes_position_check check(position between 0 and 10);
-- Fonts gain two percentage points; split the remaining 26.75% empty chance
-- across four sectors. Stable existing IDs preserve historical spin results.
update public.daily_wheel_prizes set weight=2130 where kind='font';
update public.daily_wheel_prizes set weight=1605 where kind='empty';
insert into public.daily_wheel_prizes(position,kind,label,weight) values(10,'empty','Sem recompensa',1605);
notify pgrst,'reload schema';
commit;
