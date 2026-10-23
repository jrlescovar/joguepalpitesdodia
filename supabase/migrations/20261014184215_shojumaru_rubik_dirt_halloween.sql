begin;

-- Event-only acquisition; retain rarity, ownership and historical rewards.
update public.box_style_catalog
set theme='halloween'
where item_kind='font' and style in ('shojumaru','rubikdirt');

do $$ begin
 if (select count(*) from public.box_style_catalog
     where style in ('shojumaru','rubikdirt') and item_kind='font'
       and theme='halloween' and rarity='epic')<>2 then
  raise exception 'Halloween font catalog update incomplete';
 end if;
end $$;

commit;
