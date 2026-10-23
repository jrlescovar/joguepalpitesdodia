begin;
set local lock_timeout='5s';
lock table public.public_profiles,public.box_inventory,public.box_style_catalog,public.player_mail,public.box_openings,public.level_drops,public.level_drop_requests,public.level_drop_xp_repairs in share row exclusive mode;

-- Remove the fonts from every account. Other cosmetics, XP and balances stay intact.
update public.public_profiles set username_font='normal',updated_at=now()
where username_font in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript');
delete from public.box_inventory where style in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript');
delete from public.player_mail where style in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript');

-- Keep anonymous opening receipts as replay guards; the removed fonts themselves
-- no longer exist in the catalog or in stored rewards.
insert into public.box_style_catalog(style,rarity,item_kind,theme)
select distinct 'removed-font-'||o.rarity,o.rarity,'font','retired'
from public.box_openings o
where o.style in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript')
on conflict(style) do nothing;
update public.box_openings set style='removed-font-'||rarity
where style in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript');
update public.level_drops set reward=(reward-'style')||'{"retired":true}'::jsonb
where reward->>'style' in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript');
update public.level_drop_xp_repairs set previous_reward=(previous_reward-'style')||'{"retired":true}'::jsonb
where previous_reward->>'style' in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript');
update public.level_drop_requests set response=jsonb_set(response,'{reward}',((response->'reward')-'style')||'{"retired":true}'::jsonb)
where response->'reward'->>'style' in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript');
delete from public.box_style_catalog where style in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript');

-- Also reject direct writes or accidental reintroduction by an old release.
alter table public.public_profiles add constraint removed_monster_kirang_dancing_fonts
check(username_font not in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript'));
alter table public.box_style_catalog add constraint removed_monster_kirang_dancing_catalog
check(style not in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript'));

do $$
begin
 if exists(select 1 from public.public_profiles where username_font in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript'))
 or exists(select 1 from public.box_style_catalog where style in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript'))
 or exists(select 1 from public.box_inventory where style in ('ewert','kiranghaerang','dancingscript','preview-ewert','preview-kiranghaerang','preview-dancingscript'))
 then raise exception 'Font removal incomplete';end if;
end $$;
notify pgrst,'reload schema';
commit;
