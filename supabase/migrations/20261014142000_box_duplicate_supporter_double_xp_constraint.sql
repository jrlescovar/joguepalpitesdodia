begin;

-- Keep historical 1.5x rewards and allow current 2x supporter rewards.
-- Epic duplicates: 200 * 2 = 400; legendary duplicates: 1000 * 2 = 2000.
alter table public.box_openings drop constraint box_openings_xp_awarded_check;
alter table public.box_openings add constraint box_openings_xp_awarded_check
 check(xp_awarded in (0,25,50,100,250,500,38,75,150,375,750,200,300,400,1000,1500,2000));

commit;
