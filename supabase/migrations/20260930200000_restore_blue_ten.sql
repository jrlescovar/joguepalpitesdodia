begin;
alter table public.public_profiles drop constraint active_blue_name_styles;
alter table public.public_profiles drop constraint active_blue_frame_styles;
alter table public.public_profiles add constraint active_blue_name_styles check(left(pass_name_style,9)<>'lab-blue-' or pass_name_style in ('lab-blue-4','lab-blue-6','lab-blue-7','lab-blue-9','lab-blue-10'));
alter table public.public_profiles add constraint active_blue_frame_styles check(left(pass_border_style,9)<>'lab-blue-' or pass_border_style in ('lab-blue-4','lab-blue-6','lab-blue-7','lab-blue-9','lab-blue-10'));
do $$ declare definition text; begin
 definition:=pg_get_functiondef('public.box_style_allowed(uuid,text,text)'::regprocedure);
 definition:=replace(definition,'(''lab-blue-4'',''lab-blue-6'',''lab-blue-7'',''lab-blue-9'')','(''lab-blue-4'',''lab-blue-6'',''lab-blue-7'',''lab-blue-9'',''lab-blue-10'')');
 execute definition;
end; $$;
notify pgrst,'reload schema';
commit;
