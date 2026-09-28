begin;
update public.public_profiles set username_font='normal' where username_font in ('anton','russoone','righteous','caveat');
alter table public.public_profiles drop constraint username_font_available;
alter table public.public_profiles add constraint username_font_available check(username_font in ('normal','blackopsone','bebasneue','orbitron','amaticsc','kalam','permanentmarker','monocraft','dancingscript','bungee','nosifer','creepster','pressstart2p','audiowide','rubikmonoone','wallpoet','luckiestguy','specialelite','greatvibes'));
insert into public.box_style_catalog(style,rarity,item_kind) values ('blackopsone','rare','font') on conflict(style) do update set rarity=excluded.rarity,item_kind=excluded.item_kind;
create or replace function public.username_font_allowed(p_profile_id uuid,p_font text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select p_font='normal' or
 (exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001) and p_font in ('bungee','nosifer','creepster','pressstart2p','audiowide','rubikmonoone','wallpoet','luckiestguy','specialelite','greatvibes')) or
 (exists(select 1 from public.box_style_catalog c where c.style=p_font and c.item_kind='font') and
 (exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001) or exists(select 1 from public.box_inventory i where i.profile_id=p_profile_id and i.kind='font' and i.style=p_font)));
$$;
revoke all on function public.username_font_allowed(uuid,text) from public,anon,authenticated;
commit;
