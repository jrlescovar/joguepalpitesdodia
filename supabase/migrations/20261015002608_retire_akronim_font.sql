begin;
update public.box_style_catalog set theme='retired' where item_kind='font' and style in ('akronim','preview-akronim');
commit;
