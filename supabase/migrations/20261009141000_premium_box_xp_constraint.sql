begin;
alter table public.box_openings drop constraint box_openings_xp_awarded_check;
alter table public.box_openings add constraint box_openings_xp_awarded_check check(xp_awarded in (0,25,50,100,250,500,38,75,150,375,750));
commit;
select 'Premium XP constraint updated' result;
