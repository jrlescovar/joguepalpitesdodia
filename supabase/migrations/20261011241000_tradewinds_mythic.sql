begin;
update public.box_style_catalog set rarity='mythic'
where style='tradewinds' and item_kind='font';
update public.box_openings set rarity='mythic'
where style='tradewinds' and kind='font';
-- Previously credited XP stays unchanged. Future box and drop draws use mythic.
do $$ begin
 if not exists(select 1 from public.box_style_catalog
  where style='tradewinds' and item_kind='font' and rarity='mythic' and theme='classic') then
  raise exception 'Trade Winds mythic catalogue update failed';
 end if;
end $$;
notify pgrst,'reload schema';
commit;
