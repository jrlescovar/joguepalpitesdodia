begin;
-- Deterministic rarity coverage; all data and this helper revert at the end.
create or replace function public.box_random_index(p_count integer) returns integer language plpgsql volatile security definer set search_path=public,pg_temp as $$
begin
 return case when p_count=100 then current_setting('test.halloween_roll')::integer else 0 end;
end;$$;
do $$
declare owner_id uuid; owner_auth uuid; request uuid; first_result jsonb; again jsonb; roll integer; other_id uuid; denied boolean:=false;
begin
 select p.id,v.auth_user_id into owner_id,owner_auth from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id=1000001;
 perform set_config('request.jwt.claim.sub',owner_auth::text,true);
 insert into public.box_balances(profile_id,balance) values(owner_id,10) on conflict(profile_id) do update set balance=10;
 foreach roll in array array[0,40,70,85,95] loop
  perform set_config('test.halloween_roll',roll::text,true);
  request:=gen_random_uuid();
  first_result:=public.open_halloween_box(request);
  again:=public.open_halloween_box(request);
  if first_result<>again then raise exception 'Opening is not idempotent'; end if;
  if not exists(select 1 from public.box_style_catalog where style=first_result->>'style' and theme='halloween') then raise exception 'Wrong catalog'; end if;
  if roll in (0,95) and first_result->>'kind'<>'background' then raise exception 'Missing background draw'; end if;
 end loop;
 if (select balance from public.box_balances where profile_id=owner_id)<>5 then raise exception 'Incorrect debit'; end if;
 perform public.set_profile_background('halloween-bats');
 if public.get_profile_background(owner_id)<>'halloween-bats' then raise exception 'Background not visible'; end if;
 perform public.set_username_font('eater');
 perform public.set_username_font('butcherman');
 perform public.set_pass_styles('halloween-pumpkin','halloween-bloodmoon');
 -- A player without the item cannot equip it through the API.
 select p.id into other_id from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id<>1000001 and v.auth_user_id is not null limit 1;
 if other_id is not null then
  delete from public.box_inventory where profile_id=other_id and style like 'halloween-%';
  perform set_config('request.jwt.claim.sub',(select auth_user_id::text from public.private_profiles where profile_id=other_id),true);
  begin perform public.set_profile_background('halloween-bats'); exception when others then denied:=true; end;
  if not denied then raise exception 'Unowned background was equipped'; end if;
  if public.box_style_allowed(other_id,'frame','halloween-pumpkin') then raise exception 'Unowned frame allowed'; end if;
 end if;
 if has_function_privilege('anon','public.open_halloween_box(uuid)','execute') then raise exception 'Anonymous access'; end if;
end;$$;
rollback;
