begin;
do $$
declare updated jsonb; target uuid;
begin
  perform set_config('request.jwt.claim.sub',(
    select auth_user_id::text from public.private_profiles
    where profile_id=(select id from public.public_profiles where player_id=1000001)
  ),true);
  target:=public.own_profile_id();
  if target is null then raise exception 'Test account not found'; end if;
  updated:=public.set_my_push_settings(true,false,true);
  if updated<>jsonb_build_object('available',true) then
    raise exception 'Settings response did not match saved values';
  end if;
  if not exists(select 1 from public.push_preferences where profile_id=target and available and not reminder and not result) then
    raise exception 'Settings were not saved';
  end if;
end;
$$;
rollback;
