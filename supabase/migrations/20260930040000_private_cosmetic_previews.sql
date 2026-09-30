begin;
-- Preview items are not inserted into loot catalogs or other players' inventories.
-- Preserve existing constraints and allow the new values only on the owner's profile.
do $$
declare entry record; prior text;
begin
 for entry in select * from (values
  ('pass_name_style_check','pass_name_style',array['preview-plasma','preview-boreal','preview-pearl','preview-volcano','preview-atlantis','preview-sakura','preview-toxic','preview-onyx','preview-supernova','preview-neon-ocean']),
  ('pass_border_style_check','pass_border_style',array['preview-plasma','preview-boreal','preview-pearl','preview-volcano','preview-atlantis','preview-sakura','preview-toxic','preview-onyx','preview-supernova','preview-neon-ocean']),
  ('username_font_available','username_font',array['preview-teko','preview-oxanium','preview-chakra','preview-exo','preview-satisfy','preview-marck','preview-gothic','preview-graduate','preview-londrina','preview-faster'])
 ) as x(constraint_name,column_name,allowed) loop
  select pg_get_expr(conbin,conrelid) into strict prior from pg_constraint
   where conrelid='public.public_profiles'::regclass and conname=entry.constraint_name;
  execute format('alter table public.public_profiles drop constraint %I',entry.constraint_name);
  execute format('alter table public.public_profiles add constraint %I check ((%s) or (%I=any(%L::text[]) and player_id=1000001))',entry.constraint_name,prior,entry.column_name,entry.allowed);
 end loop;
end;$$;

create or replace function public.box_style_allowed(p_profile_id uuid,p_kind text,p_style text)
returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
 select case when left(p_style,8)='preview-' then
  p_style=any(array['preview-plasma','preview-boreal','preview-pearl','preview-volcano','preview-atlantis','preview-sakura','preview-toxic','preview-onyx','preview-supernova','preview-neon-ocean']) and p_kind in ('name','frame')
  and p_profile_id=public.own_profile_id()
  and exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001)
 else p_style='none' or (p_style<>'orange' and (
  exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001)
  or exists(select 1 from public.box_inventory i where i.profile_id=p_profile_id and i.kind=p_kind and i.style=p_style)
 )) end;
$$;

create or replace function public.username_font_allowed(p_profile_id uuid,p_font text)
returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
 select case when left(p_font,8)='preview-' then
  p_font=any(array['preview-teko','preview-oxanium','preview-chakra','preview-exo','preview-satisfy','preview-marck','preview-gothic','preview-graduate','preview-londrina','preview-faster']) and p_profile_id=public.own_profile_id()
  and exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001)
 else p_font='normal' or (
  exists(select 1 from public.box_style_catalog c where c.style=p_font and c.item_kind='font') and (
   exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001)
   or exists(select 1 from public.box_inventory i where i.profile_id=p_profile_id and i.kind='font' and i.style=p_font)
  )) end;
$$;
revoke all on function public.box_style_allowed(uuid,text,text) from public,anon,authenticated;
revoke all on function public.username_font_allowed(uuid,text) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
