begin;
update public.box_style_catalog set rarity='epic' where style='rubikvinyl' and item_kind='font';
update public.box_openings set rarity='epic' where style='rubikvinyl' and kind='font';
-- Previously credited XP remains unchanged; future draws use the epic tier.
commit;
