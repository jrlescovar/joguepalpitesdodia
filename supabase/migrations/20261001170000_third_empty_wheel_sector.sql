begin;
alter table public.daily_wheel_prizes drop constraint daily_wheel_prizes_position_check;
alter table public.daily_wheel_prizes add constraint daily_wheel_prizes_position_check check(position between 0 and 9);
-- Split the existing 23.75% no-reward probability over three sectors.
-- Every box prize retains 11.875%, and Apoiador retains exactly 5%.
update public.daily_wheel_prizes set weight=case kind when 'supporter' then 1200 when 'empty' then 1900 else 2850 end;
insert into public.daily_wheel_prizes(position,kind,label,weight) values(9,'empty','Sem recompensa',1900);
notify pgrst,'reload schema';
commit;
