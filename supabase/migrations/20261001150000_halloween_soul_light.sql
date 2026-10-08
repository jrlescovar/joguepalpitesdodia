begin;
-- Preserve the style ID/effect and existing equipped profiles. NULL item_kind
-- supplies separate name-color and frame prizes in the Halloween catalog.
insert into public.box_style_catalog(style,rarity,item_kind,theme)
 values('lab-blue-6','legendary',null,'halloween')
 on conflict(style) do update set rarity=excluded.rarity,item_kind=excluded.item_kind,theme=excluded.theme;

-- Winners may equip this former private style; other preview restrictions stay.
do $$
declare item record; col text; definition text;
begin
 for item in select conname,pg_get_constraintdef(oid) as expression from pg_constraint
  where conrelid='public.public_profiles'::regclass and conname in ('active_blue_name_styles','active_blue_frame_styles') loop
  col:=case item.conname when 'active_blue_name_styles' then 'pass_name_style' else 'pass_border_style' end;
  if left(item.expression,6)<>'CHECK ' then raise exception 'Unexpected style constraint'; end if;
  execute format('alter table public.public_profiles drop constraint %I',item.conname);
  execute format('alter table public.public_profiles add constraint %I check ((%s) or %I=''lab-blue-6'')',item.conname,substring(item.expression from 7),col);
 end loop;
 definition:=pg_get_functiondef('public.box_style_allowed(uuid,text,text)'::regprocedure);
 if position('case when p_style in (''lab-blue-9'',''lab-blue-10-jade-sky'')' in definition)=0 then raise exception 'Unexpected event access definition'; end if;
 definition:=replace(definition,'case when p_style in (''lab-blue-9'',''lab-blue-10-jade-sky'')','case when p_style in (''lab-blue-6'',''lab-blue-9'',''lab-blue-10-jade-sky'')');
 execute definition;
end;$$;
notify pgrst,'reload schema';
commit;
