begin;
set local statement_timeout='30s';
do $$
declare existing_id uuid; new_id uuid:=gen_random_uuid(); previous_date timestamptz;
begin
 select profile_id into existing_id from public.beta_tester_legacy_awards limit 1;
 if existing_id is null then raise exception 'No preserved holders';end if;
 if not(public.get_public_profile(existing_id)->>'betaTester')::boolean or not(public.profile_json(existing_id)->>'betaTester')::boolean then raise exception 'Existing medal missing';end if;
 select created_at into previous_date from public.public_profiles where id=existing_id;
 update public.public_profiles set created_at=now() where id=existing_id;
 if not(public.get_public_profile(existing_id)->>'betaTester')::boolean then raise exception 'Medal depends on date';end if;
 insert into public.public_profiles(id,player_id,username,avatar_color,created_at) values(new_id,99160001,'v1betatest','#3b82f6',date '2026-09-01');
 if (public.get_public_profile(new_id)->>'betaTester')::boolean or (public.profile_json(new_id)->>'betaTester')::boolean then raise exception 'New account received medal';end if;
 begin
  insert into public.beta_tester_legacy_awards(profile_id) values(new_id);
  raise exception 'Award accepted';
 exception when raise_exception then
  if sqlerrm='Award accepted' then raise;end if;
 end;
 if has_table_privilege('authenticated','public.beta_tester_legacy_awards','insert') or has_function_privilege('anon','public.has_legacy_beta_medal(uuid)','execute') then raise exception 'Permissions leaked';end if;
end $$;
select count(*) preserved_medals from public.beta_tester_legacy_awards;
rollback;
