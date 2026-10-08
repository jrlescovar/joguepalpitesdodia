begin;
create or replace function public.wheel_random_index(p_count integer) returns integer
language plpgsql volatile set search_path=public,pg_temp as $$
begin return current_setting('test.owner_wheel_draw')::integer; end;$$;
do $$
declare owner_id uuid; owner_auth uuid; other_id uuid; other_auth uuid; today date:=(now() at time zone 'America/Sao_Paulo')::date;
 state jsonb; result jsonb; first_result jsonb; again jsonb; first_request uuid; second_request uuid; balance_before integer; balance_after integer; empty_sector record;
begin
 select p.id,v.auth_user_id into strict owner_id,owner_auth from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id=1000001;
 select p.id,v.auth_user_id into strict other_id,other_auth from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id<>1000001 and v.auth_user_id is not null order by p.player_id limit 1;
 delete from public.daily_wheel_spins where profile_id in(owner_id,other_id);
 delete from public.daily_wheel_tickets where profile_id in(owner_id,other_id);
 delete from public.picks where profile_id in(owner_id,other_id) and prediction_day=today;
 perform set_config('request.jwt.claim.sub',owner_auth::text,true);
 state:=public.get_daily_wheel_state();
 if not (state->>'unlimited')::boolean or not (state->>'eligible')::boolean or (state->>'used')::boolean then raise exception 'Owner unlimited not available without picks'; end if;
 -- No prize: consumed requests remain repeatable, but new requests are unlimited.
 perform set_config('test.owner_wheel_draw','0',true);
 first_request:=gen_random_uuid();first_result:=public.spin_daily_wheel(first_request);
 if first_result->>'kind'<>'empty' then raise exception 'Incorrect first sector'; end if;
 select coalesce(balance,0) into balance_before from public.box_balances where profile_id=owner_id;
 perform set_config('test.owner_wheel_draw','1845',true);
 second_request:=gen_random_uuid();result:=public.spin_daily_wheel(second_request);
 if result->>'kind'<>'classic' then raise exception 'Owner second spin blocked/wrong reward'; end if;
 select balance into balance_after from public.box_balances where profile_id=owner_id;
 if balance_after<>balance_before+1 then raise exception 'Owner reward not credited'; end if;
 again:=public.spin_daily_wheel(second_request);
 if again<>result or (select balance from public.box_balances where profile_id=owner_id)<>balance_after then raise exception 'Owner UUID retry redelivered'; end if;
 if public.spin_daily_wheel(first_request)<>first_result then raise exception 'Older owner UUID lost its result'; end if;
 state:=public.get_daily_wheel_state();
 if (state->>'used')::boolean or not (state->>'unlimited')::boolean or state->'result'<>result then raise exception 'Owner latest result/state incorrect'; end if;
 if (select count(*) from public.daily_wheel_spins where profile_id=owner_id and day_id=today)<>2 or exists(select 1 from public.daily_wheel_spins where profile_id=owner_id and not owner_test) then raise exception 'Owner spin ledger incorrect'; end if;
 -- The exception does not leak to an ordinary account or bypass its daily cap.
 perform set_config('request.jwt.claim.sub',other_auth::text,true);
 state:=public.get_daily_wheel_state();
 if (state->>'unlimited')::boolean or (state->>'eligible')::boolean then raise exception 'Unlimited leaked to ordinary account'; end if;
 insert into public.daily_wheel_tickets(profile_id,day_id) values(other_id,today);
 perform set_config('test.owner_wheel_draw','0',true);
 result:=public.spin_daily_wheel(gen_random_uuid());
 begin perform public.spin_daily_wheel(gen_random_uuid());raise exception 'Expected normal daily cap'; exception when others then if sqlerrm not like 'Você já usou%' then raise; end if; end;
 if exists(select 1 from public.daily_wheel_spins where profile_id=other_id and owner_test) then raise exception 'Normal account tagged owner'; end if;
 -- Database uniqueness still protects normal accounts independently of RPCs.
 begin
  insert into public.daily_wheel_spins(profile_id,day_id,request_id,result) values(other_id,today,gen_random_uuid(),result);
  raise exception 'Expected database daily uniqueness';
 exception when unique_violation then null; end;
 if (select array_agg(position order by position) from public.daily_wheel_prizes where kind='empty')<>array[0,4,5,9,10]::smallint[]
 or (select array_agg(position order by position) from public.daily_wheel_prizes where kind='classic')<>array[1]::smallint[] then raise exception 'Wrong wheel prize layout'; end if;
 if (select sum(weight) from public.daily_wheel_prizes)<>24000 or (select weight from public.daily_wheel_prizes where kind='supporter')<>1200
 or (select sum(weight) from public.daily_wheel_prizes where kind='empty')<>10230
 or (select weight from public.daily_wheel_prizes where kind='halloween')<>1890
 or (select weight from public.daily_wheel_prizes where kind='font')<>2130 then raise exception 'Probabilities changed'; end if;
 perform set_config('request.jwt.claim.sub',owner_auth::text,true);
 for empty_sector in select position,coalesce((select sum(weight) from public.daily_wheel_prizes prior where prior.position<p.position),0)::integer draw from public.daily_wheel_prizes p where kind='empty' loop
  perform set_config('test.owner_wheel_draw',empty_sector.draw::text,true);
  first_request:=gen_random_uuid();result:=public.spin_daily_wheel(first_request);
  if result->>'kind'<>'empty' or (result->>'position')::integer<>empty_sector.position or result->'boxes'<>'{}'::jsonb then raise exception 'Empty sector delivered wrong result'; end if;
  if public.spin_daily_wheel(first_request)<>result then raise exception 'Empty sector retry changed result'; end if;
 end loop;
 if (select balance from public.box_balances where profile_id=owner_id)<>balance_after then raise exception 'Empty sectors awarded boxes'; end if;
end;$$;
rollback;
