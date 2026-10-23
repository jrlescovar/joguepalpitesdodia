begin;

-- Retire both released and legacy IDs. Preserve all earned XP and other rewards.
update public.public_profiles set username_font='normal'
where username_font in ('bungeeshade','preview-bungeeshade');
delete from public.box_inventory where style in ('bungeeshade','preview-bungeeshade');
delete from public.box_openings where style in ('bungeeshade','preview-bungeeshade');
delete from public.player_mail where style in ('bungeeshade','preview-bungeeshade');
delete from public.box_style_catalog where style in ('bungeeshade','preview-bungeeshade');

do $$
begin
 if not exists(select 1 from pg_constraint where conrelid='public.public_profiles'::regclass and conname='retired_bungee_shade_font') then
  alter table public.public_profiles add constraint retired_bungee_shade_font
   check(username_font not in ('bungeeshade','preview-bungeeshade'));
 end if;
 if exists(select 1 from public.box_style_catalog where style in ('bungeeshade','preview-bungeeshade'))
 or exists(select 1 from public.box_inventory where style in ('bungeeshade','preview-bungeeshade'))
 or exists(select 1 from public.public_profiles where username_font in ('bungeeshade','preview-bungeeshade')) then
  raise exception 'Bungee Shade retirement incomplete';
 end if;
end $$;
notify pgrst,'reload schema';
commit;
