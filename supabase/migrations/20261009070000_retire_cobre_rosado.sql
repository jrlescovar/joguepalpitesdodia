begin;
delete from public.box_inventory where kind in ('name','frame') and style='myth-plum-copper';
update public.box_style_catalog set theme='retired' where style='myth-plum-copper';
alter table public.public_profiles add constraint retired_cobre_rosado_name check(pass_name_style<>'myth-plum-copper');
alter table public.public_profiles add constraint retired_cobre_rosado_frame check(pass_border_style<>'myth-plum-copper');
notify pgrst,'reload schema';
commit;
select (select count(*) from public.box_inventory where style='myth-plum-copper') inventory,(select theme from public.box_style_catalog where style='myth-plum-copper') theme,(select count(*) from public.box_openings where style='myth-plum-copper') preserved_openings;
