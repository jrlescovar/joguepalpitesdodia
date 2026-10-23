begin;
set local lock_timeout='5s';
lock table public.public_profiles,public.box_inventory,public.box_style_catalog,public.player_mail,public.box_openings,public.level_drops,public.level_drop_requests,public.level_drop_xp_repairs in share row exclusive mode;

create temporary table removed_profile_fonts(style text primary key) on commit drop;
insert into removed_profile_fonts values
 ('blackopsone'),('audiowide'),('arbutus'),('miltoniantattoo'),('creepster'),
 ('specialelite'),('rubikdirt'),('shojumaru'),('allertastencil'),('barrio'),
 ('rubikmoonrocks'),('rampartone'),('kumaroneoutline');
insert into removed_profile_fonts select 'preview-'||style from removed_profile_fonts;

-- Unequip only the selected fonts; other profile data and cosmetics are preserved.
update public.public_profiles set username_font='normal',updated_at=now()
where username_font in(select style from removed_profile_fonts);
delete from public.box_inventory where style in(select style from removed_profile_fonts);
delete from public.player_mail where style in(select style from removed_profile_fonts);

-- Retain anonymous receipts so retrying a previous opening cannot grant another item.
insert into public.box_style_catalog(style,rarity,item_kind,theme)
select distinct 'removed-font-'||o.rarity,o.rarity,'font','retired'
from public.box_openings o where o.style in(select style from removed_profile_fonts)
on conflict(style) do nothing;
update public.box_openings set style='removed-font-'||rarity
where style in(select style from removed_profile_fonts);
update public.level_drops set reward=(reward-'style')||'{"retired":true}'::jsonb
where reward->>'style' in(select style from removed_profile_fonts);
update public.level_drop_xp_repairs set previous_reward=(previous_reward-'style')||'{"retired":true}'::jsonb
where previous_reward->>'style' in(select style from removed_profile_fonts);
update public.level_drop_requests set response=jsonb_set(response,'{reward}',((response->'reward')-'style')||'{"retired":true}'::jsonb)
where response->'reward'->>'style' in(select style from removed_profile_fonts);
delete from public.box_style_catalog where style in(select style from removed_profile_fonts);

-- Old clients and direct writes must not reintroduce these fonts or preview aliases.
do $$
declare removed text[];
begin
 select array_agg(style order by style) into removed from removed_profile_fonts;
 if not exists(select 1 from pg_constraint where conrelid='public.public_profiles'::regclass and conname='removed_thirteen_circled_fonts') then
  execute format('alter table public.public_profiles add constraint removed_thirteen_circled_fonts check(username_font <> all(%L::text[]))',removed);
 end if;
 if not exists(select 1 from pg_constraint where conrelid='public.box_style_catalog'::regclass and conname='removed_thirteen_circled_catalog') then
  execute format('alter table public.box_style_catalog add constraint removed_thirteen_circled_catalog check(style <> all(%L::text[]))',removed);
 end if;
 if exists(select 1 from public.public_profiles where username_font=any(removed))
 or exists(select 1 from public.box_style_catalog where style=any(removed))
 or exists(select 1 from public.box_inventory where style=any(removed))
 or exists(select 1 from public.player_mail where style=any(removed))
 or exists(select 1 from public.box_openings where style=any(removed))
 or exists(select 1 from public.level_drops where reward->>'style'=any(removed))
 or exists(select 1 from public.level_drop_xp_repairs where previous_reward->>'style'=any(removed))
 or exists(select 1 from public.level_drop_requests where response->'reward'->>'style'=any(removed))
 then raise exception 'Circled font removal incomplete'; end if;
end $$;
notify pgrst,'reload schema';
commit;
