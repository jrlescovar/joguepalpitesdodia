begin;
insert into public.box_style_catalog(style,rarity,item_kind,theme)
values ('legend-lunar-prism','legendary',null,'classic')
on conflict(style) do update set rarity=excluded.rarity,item_kind=excluded.item_kind,theme=excluded.theme;
do $$ declare r record; col text; begin
 for r in select conname,pg_get_constraintdef(oid) definition from pg_constraint where conrelid='public.public_profiles'::regclass and conname in ('pass_name_style_check','pass_border_style_check') loop
  if position('legend-lunar-prism' in r.definition)=0 then
   col:=case when r.conname='pass_name_style_check' then 'pass_name_style' else 'pass_border_style' end;
   execute format('alter table public.public_profiles drop constraint %I',r.conname);
   execute format('alter table public.public_profiles add constraint %I check ((%s) or %I=''legend-lunar-prism'')',r.conname,substring(r.definition from 8 for length(r.definition)-8),col);
  end if;
 end loop;
end $$;
notify pgrst,'reload schema';
commit;
