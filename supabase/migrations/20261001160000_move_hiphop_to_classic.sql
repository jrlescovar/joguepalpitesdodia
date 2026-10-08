begin;
-- Both the personalization and font-only draws use the classic font catalog.
-- Keep the stable font ID, legendary rarity and existing inventory unlocks.
do $$
begin
 update public.box_style_catalog set theme='classic'
 where style='sedgwickavedisplay' and item_kind='font' and rarity='legendary';
 if not found then raise exception 'HipHop legendary font not found'; end if;
end;$$;
notify pgrst,'reload schema';
commit;
