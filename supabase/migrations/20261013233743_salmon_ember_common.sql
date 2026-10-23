begin;
update public.box_style_catalog set rarity='common' where style in ('ember','green-gold') and item_kind is null;
do $$begin
 if (select count(*) from public.box_style_catalog where style in ('ember','green-gold') and item_kind is null and rarity='common' and theme='classic')<>2 then raise exception 'Salmão/Braza rarity update failed';end if;
end $$;
commit;
