begin;
update public.box_style_catalog set rarity='mythic'
where style='lilac-silver' and item_kind is null;
update public.box_openings set rarity='mythic'
where style='lilac-silver' and kind in ('name','frame');
-- Keep ownership, equipped styles, and previously credited XP unchanged.
do $$ begin
 if not exists(select 1 from public.box_style_catalog
  where style='lilac-silver' and item_kind is null and rarity='mythic' and theme='classic') then
  raise exception 'Prata Lilas mythic catalogue update failed';
 end if;
end $$;
notify pgrst,'reload schema';
commit;
