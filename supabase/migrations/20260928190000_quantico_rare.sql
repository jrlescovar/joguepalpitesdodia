begin;
update public.box_style_catalog set rarity='rare' where style='quantico' and item_kind='font';
commit;
