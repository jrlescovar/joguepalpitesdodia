begin;
alter table public.public_profiles drop constraint username_font_available;
alter table public.public_profiles add constraint username_font_available check(username_font in ('normal','monocraft','dancingscript','bebasneue','amaticsc','kalam','orbitron','bangers','cinzel','rajdhani','permanentmarker'));
create or replace function public.username_font_allowed(p_profile_id uuid,p_font text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select p_font='normal' or
 (exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001) and p_font in ('orbitron','bangers','cinzel','rajdhani','permanentmarker')) or
 (exists(select 1 from public.box_style_catalog c where c.style=p_font and c.item_kind='font') and
 (exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001) or exists(select 1 from public.box_inventory i where i.profile_id=p_profile_id and i.kind='font' and i.style=p_font)));
$$;
revoke all on function public.username_font_allowed(uuid,text) from public,anon,authenticated;
commit;
