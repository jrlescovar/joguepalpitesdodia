begin;
do $$
declare accepted text;
begin
 select pg_get_expr(conbin,conrelid) into accepted from pg_constraint
 where conrelid='public.public_profiles'::regclass and conname='username_font_available';
 if accepted is null then raise exception 'Font constraint not found'; end if;
 alter table public.public_profiles drop constraint username_font_available;
 execute 'alter table public.public_profiles add constraint username_font_available check (('||accepted||') or username_font in (''eater'',''butcherman''))';
end;$$;
commit;
