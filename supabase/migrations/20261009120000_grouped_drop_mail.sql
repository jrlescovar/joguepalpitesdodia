begin;
create function public.receive_all_level_drops() returns integer language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); quantity integer;
begin
 if not exists(select 1 from public.public_profiles where id=target and player_id=1000001 and lower(username)='zaotips') then raise exception 'Prévia exclusiva do zaotips.'; end if;
 perform public.get_level_drops();
 update public.level_drops set received_at=now() where profile_id=target and received_at is null and status<>'claimed';
 get diagnostics quantity=row_count;
 return quantity;
end $$;
revoke all on function public.receive_all_level_drops() from public,anon;
grant execute on function public.receive_all_level_drops() to authenticated;
notify pgrst,'reload schema';
commit;
select 'Grouped claim ready' result;
