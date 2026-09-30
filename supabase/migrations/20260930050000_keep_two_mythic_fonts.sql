begin;
-- Retire the private previews and preserve the owner's two selected fonts.
alter table public.public_profiles drop constraint username_font_available;
update public.public_profiles set
 pass_name_style=case when pass_name_style like 'preview-%' then 'none' else pass_name_style end,
 pass_border_style=case when pass_border_style like 'preview-%' then 'none' else pass_border_style end,
 username_font=case username_font when 'preview-marck' then 'marckscript' when 'preview-gothic' then 'unifrakturcook'
  else case when username_font like 'preview-%' then 'normal' else username_font end end
where pass_name_style like 'preview-%' or pass_border_style like 'preview-%' or username_font like 'preview-%';
alter table public.public_profiles add constraint username_font_available check(username_font in
 ('normal','blackopsone','audiowide','bebasneue','orbitron','creepster','luckiestguy','amaticsc','kalam','permanentmarker','specialelite','monocraft','dancingscript','metalmania','rye','frijole','quantico','eater','butcherman','marckscript','unifrakturcook'));
do $$
declare entry record; prior text;
begin
 for entry in select * from (values ('pass_name_style_check','pass_name_style'),('pass_border_style_check','pass_border_style')) as x(constraint_name,column_name) loop
  select pg_get_expr(conbin,conrelid) into strict prior from pg_constraint where conrelid='public.public_profiles'::regclass and conname=entry.constraint_name;
  execute format('alter table public.public_profiles drop constraint %I',entry.constraint_name);
  execute format('alter table public.public_profiles add constraint %I check ((%s) and left(%I,8)<>''preview-'')',entry.constraint_name,prior,entry.column_name);
 end loop;
end;$$;
delete from public.box_inventory where style like 'preview-%';
insert into public.box_style_catalog(style,rarity,item_kind,theme) values
 ('marckscript','mythic','font','classic'),('unifrakturcook','mythic','font','classic');
insert into public.box_inventory(profile_id,kind,style)
 select id,'font',font from public.public_profiles cross join (values ('marckscript'),('unifrakturcook')) x(font)
 where player_id=1000001 on conflict do nothing;
create or replace function public.box_style_allowed(p_profile_id uuid,p_kind text,p_style text)
returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
 select p_style='none' or (p_style<>'orange' and left(p_style,8)<>'preview-' and (
  exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001)
  or exists(select 1 from public.box_inventory i where i.profile_id=p_profile_id and i.kind=p_kind and i.style=p_style)
 ));
$$;
create or replace function public.username_font_allowed(p_profile_id uuid,p_font text)
returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
 select p_font='normal' or (
  exists(select 1 from public.box_style_catalog c where c.style=p_font and c.item_kind='font') and (
   exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001)
   or exists(select 1 from public.box_inventory i where i.profile_id=p_profile_id and i.kind='font' and i.style=p_font)
  ));
$$;
notify pgrst,'reload schema';
commit;
