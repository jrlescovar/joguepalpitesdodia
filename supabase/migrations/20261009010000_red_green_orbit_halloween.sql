begin;
insert into public.box_style_catalog(style,rarity,item_kind,theme) values
 ('lab-blue-9-red-orbit','legendary',null,'halloween'),
 ('lab-blue-9-green-orbit','legendary',null,'halloween')
on conflict(style) do update set rarity=excluded.rarity,item_kind=excluded.item_kind,theme=excluded.theme;
do $$ declare r record; col text; definition text; begin
 for r in select conname,pg_get_constraintdef(oid) definition from pg_constraint where conrelid='public.public_profiles'::regclass and conname in ('pass_name_style_check','pass_border_style_check','active_blue_name_styles','active_blue_frame_styles') loop
  col:=case when r.conname in ('pass_name_style_check','active_blue_name_styles') then 'pass_name_style' else 'pass_border_style' end;
  execute format('alter table public.public_profiles drop constraint %I',r.conname);
  execute format('alter table public.public_profiles add constraint %I check ((%s) or %I in (''lab-blue-9-red-orbit'',''lab-blue-9-green-orbit''))',r.conname,substring(r.definition from 8 for length(r.definition)-8),col);
 end loop;
 definition:=pg_get_functiondef('public.box_style_allowed(uuid,text,text)'::regprocedure);
 if position('lab-blue-9-red-orbit' in definition)=0 then
  if position('p_style in (''lab-blue-6'',''lab-blue-9'',''lab-blue-10-jade-sky'') then' in definition)=0 then raise exception 'Unexpected box_style_allowed definition'; end if;
  definition:=replace(definition,'p_style in (''lab-blue-6'',''lab-blue-9'',''lab-blue-10-jade-sky'') then','p_style in (''lab-blue-6'',''lab-blue-9'',''lab-blue-10-jade-sky'',''lab-blue-9-red-orbit'',''lab-blue-9-green-orbit'') then');
  execute definition;
 end if;
 if not exists(select 1 from public.public_profiles where player_id=1000001 and lower(username)='zaotips') then raise exception 'zaotips profile not found'; end if;
end $$;
insert into public.box_inventory(profile_id,kind,style)
select p.id,k.kind,s.style from public.public_profiles p cross join (values ('name'),('frame')) k(kind) cross join (values ('lab-blue-9-red-orbit'),('lab-blue-9-green-orbit')) s(style)
where p.player_id=1000001 and lower(p.username)='zaotips'
on conflict(profile_id,kind,style) do nothing;
notify pgrst,'reload schema';
commit;
select c.style,c.rarity,c.theme,i.kind,p.username,public.box_style_allowed(p.id,i.kind,c.style) equip_allowed from public.box_style_catalog c join public.box_inventory i on i.style=c.style join public.public_profiles p on p.id=i.profile_id where p.player_id=1000001 and c.style in ('lab-blue-9-red-orbit','lab-blue-9-green-orbit') order by c.style,i.kind;
