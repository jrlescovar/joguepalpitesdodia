begin;
update public.box_style_catalog set rarity='legendary' where style='caesardressing' and item_kind='font';
update public.box_openings set rarity='legendary' where style='caesardressing' and kind='font';
-- Preserve previously credited XP; future draws use the legendary tier.
commit;
