begin;
alter table public.picks drop constraint picks_xp_awarded_check;
alter table public.picks add constraint picks_xp_awarded_check check(xp_awarded>=0 and xp_awarded<=50);
commit;
