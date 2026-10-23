begin;

-- Retire both released and legacy IDs. Preserve all earned XP and other rewards.
update public.public_profiles set username_font='normal'
where username_font in ('rubikbeastly','preview-rubikbeastly');
delete from public.box_inventory where style in ('rubikbeastly','preview-rubikbeastly');
delete from public.box_openings where style in ('rubikbeastly','preview-rubikbeastly');
delete from public.player_mail where style in ('rubikbeastly','preview-rubikbeastly');
delete from public.box_style_catalog where style in ('rubikbeastly','preview-rubikbeastly');

do $$
begin
 if not exists(select 1 from pg_constraint where conrelid='public.public_profiles'::regclass and conname='retired_rubik_beastly_font') then
  alter table public.public_profiles add constraint retired_rubik_beastly_font
   check(username_font not in ('rubikbeastly','preview-rubikbeastly'));
 end if;
 if exists(select 1 from public.box_style_catalog where style in ('rubikbeastly','preview-rubikbeastly'))
 or exists(select 1 from public.box_inventory where style in ('rubikbeastly','preview-rubikbeastly'))
 or exists(select 1 from public.public_profiles where username_font in ('rubikbeastly','preview-rubikbeastly')) then
  raise exception 'Rubik Beastly retirement incomplete';
 end if;
end $$;
notify pgrst,'reload schema';
commit;
