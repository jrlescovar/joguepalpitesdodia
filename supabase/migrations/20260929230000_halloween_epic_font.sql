begin;

-- Halloween is an event-only epic font, so classic draws must exclude it.
update public.box_style_catalog
set theme = 'halloween', rarity = 'epic'
where style = 'creepster' and item_kind = 'font';

commit;
