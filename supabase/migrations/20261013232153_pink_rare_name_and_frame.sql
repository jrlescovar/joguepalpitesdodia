begin;
-- The shared style row controls both the name color and frame pools.
update public.box_style_catalog set rarity='rare' where style='pink' and item_kind is null;
do $$begin
 if not exists(select 1 from public.box_style_catalog where style='pink' and rarity='rare' and item_kind is null and theme='classic') then
  raise exception 'Pink rarity update failed';
 end if;
end;$$;
-- Historical opening rewards and owned/equipped items remain intact.
commit;
