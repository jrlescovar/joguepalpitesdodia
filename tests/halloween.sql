begin;
-- Deterministic rarity coverage; all data and this helper revert at the end.
create or replace function public.box_random_index(p_count integer) returns integer language plpgsql volatile security definer set search_path=public,pg_temp as $$
begin
 return case when p_count=100 then current_setting('test.halloween_roll')::integer else 0 end;
end;$$;
do $$
declare owner_id uuid; owner_auth uuid; request uuid; first_result jsonb; again jsonb; roll integer; other_id uuid; classic_balance integer;
begin
 select p.id,v.auth_user_id into owner_id,owner_auth from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id=1000001;
 perform set_config('request.jwt.claim.sub',owner_auth::text,true);
 select balance into classic_balance from public.box_balances where profile_id=owner_id;
 insert into public.halloween_box_balances(profile_id,balance) values(owner_id,10) on conflict(profile_id) do update set balance=10;
 foreach roll in array array[0,59,60,89,90,99] loop
  perform set_config('test.halloween_roll',roll::text,true);
  request:=gen_random_uuid();
  first_result:=public.open_halloween_box(request);
  again:=public.open_halloween_box(request);
  if first_result<>again then raise exception 'Opening is not idempotent'; end if;
  if not exists(select 1 from public.box_style_catalog where style=first_result->>'style' and theme='halloween') then raise exception 'Wrong catalog'; end if;
  if first_result->>'rarity'<>(case when roll<60 then 'epic' when roll<90 then 'mythic' else 'legendary' end) then raise exception 'Incorrect rarity'; end if;
  if first_result->>'kind'='background' then raise exception 'Retired background drawn'; end if;
 end loop;
 if (select balance from public.halloween_box_balances where profile_id=owner_id)<>4 then raise exception 'Incorrect debit'; end if;
 if (select balance from public.box_balances where profile_id=owner_id) is distinct from classic_balance then raise exception 'Classic balance changed'; end if;
 perform public.set_username_font('eater');
 perform public.set_username_font('butcherman');
 perform public.set_pass_styles('halloween-pumpkin','halloween-bloodmoon');
 -- A player without the item cannot equip it through the API.
 select p.id into other_id from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id<>1000001 and v.auth_user_id is not null limit 1;
 if other_id is not null then
  delete from public.box_inventory where profile_id=other_id and style like 'halloween-%';
  perform set_config('request.jwt.claim.sub',(select auth_user_id::text from public.private_profiles where profile_id=other_id),true);
  if public.box_style_allowed(other_id,'frame','halloween-pumpkin') then raise exception 'Unowned frame allowed'; end if;
 end if;
 perform public.credit_halloween_box_purchase(owner_id,'cs_halloween_qa_test',2,321);
 perform public.credit_halloween_box_purchase(owner_id,'cs_halloween_qa_test',2,321);
 if (select balance from public.halloween_box_balances where profile_id=owner_id)<>6 then raise exception 'Purchase idempotency failed'; end if;
 if has_function_privilege('authenticated','public.credit_halloween_box_purchase(uuid,text,integer,integer)','execute') then raise exception 'Player can credit purchases'; end if;
 if has_function_privilege('anon','public.open_halloween_box(uuid)','execute') then raise exception 'Anonymous access'; end if;
end;$$;
rollback;
