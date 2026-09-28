begin;
update public.public_profiles set username_font='normal' where username_font='patrickhand';
alter table public.public_profiles drop constraint username_font_available;
alter table public.public_profiles add constraint username_font_available check(username_font in ('normal','monocraft','dancingscript','bebasneue','amaticsc','kalam'));
create or replace function public.set_username_font(p_font text) returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id();
begin
 if not exists(select 1 from public.public_profiles where id=target and player_id=1000001) then raise exception 'Fonte indisponível para esta conta.'; end if;
 if p_font is null or p_font not in ('normal','monocraft','dancingscript','bebasneue','amaticsc','kalam') then raise exception 'Fonte inválida.'; end if;
 update public.public_profiles set username_font=p_font where id=target;
 return public.profile_json(target);
end;
$$;
notify pgrst, 'reload schema';
commit;
