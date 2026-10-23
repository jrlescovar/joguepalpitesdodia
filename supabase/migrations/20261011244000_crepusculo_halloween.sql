begin;
-- Both name and frame move together; existing ownership and rarity are preserved.
update public.box_style_catalog set theme='halloween'
where style='legend-arcane-twilight' and item_kind is null;
do $$ begin
 if not exists(select 1 from public.box_style_catalog
  where style='legend-arcane-twilight' and theme='halloween'
   and item_kind is null and rarity='legendary') then
  raise exception 'Crepusculo Halloween catalogue update failed';
 end if;
end $$;
notify pgrst,'reload schema';
commit;
