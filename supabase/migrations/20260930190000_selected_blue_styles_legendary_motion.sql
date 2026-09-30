begin;
update public.public_profiles set pass_name_style='none' where pass_name_style in ('lab-blue-1','lab-blue-2','lab-blue-3','lab-blue-5','lab-blue-8','lab-blue-10');
update public.public_profiles set pass_border_style='none' where pass_border_style in ('lab-blue-1','lab-blue-2','lab-blue-3','lab-blue-5','lab-blue-8','lab-blue-10');
alter table public.public_profiles add constraint active_blue_name_styles check(left(pass_name_style,9)<>'lab-blue-' or pass_name_style in ('lab-blue-4','lab-blue-6','lab-blue-7','lab-blue-9'));
alter table public.public_profiles add constraint active_blue_frame_styles check(left(pass_border_style,9)<>'lab-blue-' or pass_border_style in ('lab-blue-4','lab-blue-6','lab-blue-7','lab-blue-9'));
do $$ declare definition text; begin
 definition:=pg_get_functiondef('public.box_style_allowed(uuid,text,text)'::regprocedure);
 definition:=replace(definition,'select (left(p_style,9)', 'select (left(p_style,9)<>''lab-blue-'' or p_style in (''lab-blue-4'',''lab-blue-6'',''lab-blue-7'',''lab-blue-9'')) and (left(p_style,9)');
 execute definition;
end; $$;
notify pgrst,'reload schema';
commit;
