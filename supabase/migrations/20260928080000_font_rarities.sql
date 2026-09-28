begin;
update public.box_style_catalog set rarity=case when style='bebasneue' then 'epic' else 'mythic' end where item_kind='font' and style in ('bebasneue','amaticsc','kalam');
commit;
