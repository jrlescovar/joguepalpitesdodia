begin;
insert into public.box_style_catalog(style,rarity,item_kind,theme)
values('legend-blood-wave','legendary',null,'classic')
on conflict(style) do update set rarity=excluded.rarity,item_kind=excluded.item_kind,theme=excluded.theme;
do $$declare constraint_row record;column_name text;begin
 for constraint_row in select conname,pg_get_constraintdef(oid) definition from pg_constraint
  where conrelid='public.public_profiles'::regclass and conname in ('pass_name_style_check','pass_border_style_check') loop
  if position('legend-blood-wave' in constraint_row.definition)=0 then
   column_name:=case when constraint_row.conname='pass_name_style_check' then 'pass_name_style' else 'pass_border_style' end;
   execute format('alter table public.public_profiles drop constraint %I',constraint_row.conname);
   execute format('alter table public.public_profiles add constraint %I check ((%s) or %I=''legend-blood-wave'')',
    constraint_row.conname,substring(constraint_row.definition from 8 for length(constraint_row.definition)-8),column_name);
  end if;
 end loop;
end;$$;
notify pgrst,'reload schema';
commit;
