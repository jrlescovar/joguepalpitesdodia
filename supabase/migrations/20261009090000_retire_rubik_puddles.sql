begin;
alter table public.public_profiles add constraint retired_rubik_puddles_font check(username_font<>'preview-rubikpuddles');
notify pgrst,'reload schema';
commit;
select conname from pg_constraint where conrelid='public.public_profiles'::regclass and conname='retired_rubik_puddles_font';
