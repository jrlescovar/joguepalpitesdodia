-- Run after the migration. Every profile, balance, pick and prize mutation rolls back.
begin;
create temporary table wheel_test_draws(id serial primary key,draw integer not null);
create or replace function public.wheel_random_index(p_count integer) returns integer
language plpgsql volatile set search_path=public,pg_temp as $$
declare target integer; draw integer;
begin
 select id,d.draw into target,draw from pg_temp.wheel_test_draws d order by id limit 1;
 if target is null or draw<0 or draw>=p_count then raise exception 'Missing/invalid controlled test draw'; end if;
 delete from pg_temp.wheel_test_draws where id=target;
 return draw;
end;$$;
create or replace function public.box_random_index(p_count integer) returns integer
language plpgsql volatile set search_path=public,pg_temp as $$
begin
 if current_setting('test.wheel_next_rarity',true)='true' then
  perform set_config('test.wheel_next_rarity','false',true);
  return current_setting('test.wheel_rarity')::integer;
 end if;
 return current_setting('test.wheel_item_index')::integer;
end;$$;
create function pg_temp.wheel_test_balances(target uuid) returns jsonb language sql as $$
 select jsonb_build_object(
 'classic',coalesce((select balance from public.box_balances where profile_id=target),0),
 'halloween',coalesce((select balance from public.halloween_box_balances where profile_id=target),0),
 'font',coalesce((select balance from public.font_box_balances where profile_id=target),0),
 'name',coalesce((select balance from public.name_box_balances where profile_id=target),0),
 'frame',coalesce((select balance from public.frame_box_balances where profile_id=target),0));
$$;
do $$
<<test>>
declare target uuid; user_id uuid; owner_id uuid; owner_auth uuid; today date:=(now() at time zone 'America/Sao_Paulo')::date;
 state jsonb; result jsonb; again jsonb; before_balances jsonb; after_balances jsonb; request uuid;
 prize record; item record; kind text; rarity_roll integer; pool_index integer; months_before integer; total_boxes integer;
begin
 select p.id,v.auth_user_id into strict target,user_id from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id<>1000001 and v.auth_user_id is not null and not public.pass_active(p.id) order by p.player_id limit 1;
 select p.id,v.auth_user_id into strict owner_id,owner_auth from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id=1000001;
 perform set_config('request.jwt.claim.sub',user_id::text,true);
 if (select sum(weight) from public.daily_wheel_prizes)<>24000 or (select weight from public.daily_wheel_prizes p where p.kind='supporter')<>1200 then raise exception 'Incorrect 5%% probability'; end if;
 if (select count(*) from public.daily_wheel_prizes)<>11 then raise exception 'Missing slots'; end if;
 delete from public.daily_wheel_spins where profile_id in(target,owner_id);
 delete from public.daily_wheel_tickets where profile_id in(target,owner_id);
 delete from public.picks where profile_id=target and prediction_day=today;
 -- Ensure current open predictions are a deterministic fixture (rolled back).
 update public.predictions set status='open',closes_at=now()+interval '1 hour' where day_id=today;
 if (select count(*) from public.predictions where day_id=today)<2 then raise exception 'Fixture needs at least two predictions today'; end if;
 state:=public.get_daily_wheel_state();
 if (state->>'eligible')::boolean then raise exception 'Player with no picks qualified'; end if;
 begin perform public.spin_daily_wheel(gen_random_uuid());raise exception 'Expected ineligible spin rejection'; exception when others then if sqlerrm not like 'Faça todos%' then raise; end if; end;
 insert into public.picks(profile_id,prediction_day,slot,option_id) select target,day_id,slot,options->0->>'id' from public.predictions where day_id=today order by slot limit 1;
 if public.ensure_daily_wheel_ticket(target,today) then raise exception 'Incomplete picks qualified'; end if;
 insert into public.picks(profile_id,prediction_day,slot,option_id) select target,day_id,slot,options->0->>'id' from public.predictions where day_id=today on conflict do nothing;
 state:=public.get_daily_wheel_state();
 if not (state->>'eligible')::boolean or (state->>'remaining')::integer<>0 then raise exception 'Existing picks did not qualify'; end if;
 if (state->>'resetsAt')::timestamptz is distinct from ((today+1)::timestamp at time zone 'America/Sao_Paulo') then raise exception 'Incorrect midnight timezone'; end if;
 if public.ensure_daily_wheel_ticket(target,today-1) or public.ensure_daily_wheel_ticket(target,today+1) then raise exception 'Client-chosen day accepted'; end if;
 -- A won ticket survives new/unanswered predictions until midnight.
 delete from public.picks where profile_id=target and prediction_day=today and slot=(select max(slot) from public.predictions where day_id=today);
 if not public.ensure_daily_wheel_ticket(target,today) then raise exception 'Earned ticket was lost'; end if;
 insert into public.picks(profile_id,prediction_day,slot,option_id) select target,day_id,slot,options->0->>'id' from public.predictions where day_id=today on conflict do nothing;
 months_before:=(public.get_profile_overview_meta(target)->>'supporterMonths')::integer;
 -- All nine positions, exact balance deltas and exactly-once request retries.
 for prize in select *,coalesce(sum(weight) over(order by position rows between unbounded preceding and 1 preceding),0)::integer as draw from public.daily_wheel_prizes order by position loop
  delete from public.daily_wheel_spins where profile_id=target and day_id=today;
  before_balances:=pg_temp.wheel_test_balances(target);
  insert into pg_temp.wheel_test_draws(draw) values(prize.draw);
  request:=gen_random_uuid();result:=public.spin_daily_wheel(request);
  if (result->>'position')::integer<>prize.position or result->>'kind'<>prize.kind then raise exception 'Incorrect server prize'; end if;
  after_balances:=pg_temp.wheel_test_balances(target);
  foreach kind in array array['classic','halloween','font','name','frame'] loop
   if (after_balances->>kind)::integer-(before_balances->>kind)::integer<>coalesce((result->'boxes'->>kind)::integer,0) then raise exception 'Incorrect % delivery',kind; end if;
  end loop;
  again:=public.spin_daily_wheel(request);
  if again<>result or pg_temp.wheel_test_balances(target)<>after_balances then raise exception 'Retry redelivered prize'; end if;
  begin perform public.spin_daily_wheel(gen_random_uuid());raise exception 'Expected second spin rejection'; exception when others then if sqlerrm not like 'Você já usou%' then raise; end if; end;
  if not (public.get_daily_wheel_state()->>'used')::boolean then raise exception 'Used spin not restored'; end if;
  if prize.kind='empty' and result->'boxes'<>'{}'::jsonb then raise exception 'Empty credited reward'; end if;
  if prize.kind='supporter' then
   if not public.pass_active(target) or (result->>'replacement')::boolean then raise exception 'Premium not activated'; end if;
   if (result->>'supporterEndsAt')::timestamptz<>now()+interval '1 month' then raise exception 'Incorrect pass period'; end if;
   if (result->'boxes'->>'classic')::integer<>7 or (result->'boxes'->>'font')::integer<>1 then raise exception 'Missing supporter benefits'; end if;
   if (public.get_profile_overview_meta(target)->>'supporterMonths')::integer<>months_before+1 then raise exception 'Missing medal month'; end if;
  end if;
 end loop;
 -- A previous-day spin does not consume today's spin, same UUID remains idempotent.
 delete from public.daily_wheel_spins where profile_id=target;
 insert into public.daily_wheel_tickets(profile_id,day_id) values(target,today-1);
 request:=gen_random_uuid();
 insert into public.daily_wheel_spins(profile_id,day_id,request_id,result) values(target,today-1,request,jsonb_build_object('dayId',today-1,'marker','yesterday'));
 if (public.get_daily_wheel_state()->>'used')::boolean then raise exception 'Yesterday consumed today'; end if;
 if public.spin_daily_wheel(request)->>'marker'<>'yesterday' then raise exception 'Midnight retry changed reward'; end if;
 -- Already active supporter: seven independent random boxes, no extension/medal.
 before_balances:=pg_temp.wheel_test_balances(target);
 delete from public.daily_wheel_spins where profile_id=target;
 insert into pg_temp.wheel_test_draws(draw) values((select sum(weight)::integer from public.daily_wheel_prizes where position<(select position from public.daily_wheel_prizes where public.daily_wheel_prizes.kind='supporter'))),(0),(1),(2),(3),(4),(0),(1);
 result:=public.spin_daily_wheel(gen_random_uuid());
 select sum(value::integer) into total_boxes from jsonb_each_text(result->'boxes');
 if not (result->>'replacement')::boolean or total_boxes<>7 or result->>'supporterEndsAt' is not null then raise exception 'Incorrect active-pass replacement'; end if;
 if (public.get_profile_overview_meta(target)->>'supporterMonths')::integer<>months_before+1 then raise exception 'Replacement added medal month'; end if;
 after_balances:=pg_temp.wheel_test_balances(target);
 foreach kind in array array['classic','halloween','font','name','frame'] loop
  if (after_balances->>kind)::integer-(before_balances->>kind)::integer<>coalesce((result->'boxes'->>kind)::integer,0) then raise exception 'Random boxes not credited'; end if;
 end loop;
 -- No authorization to manipulate balances, tickets, odds or reward helpers.
 foreach kind in array array['name_box_balances','frame_box_balances','daily_wheel_tickets','daily_wheel_spins','daily_wheel_prizes'] loop
  if has_table_privilege('authenticated','public.'||kind,'SELECT,INSERT,UPDATE,DELETE') or has_table_privilege('anon','public.'||kind,'SELECT,INSERT,UPDATE,DELETE') then raise exception 'Exposed wheel table %',kind; end if;
  if not (select relrowsecurity from pg_class where oid=('public.'||kind)::regclass) then raise exception 'Missing RLS'; end if;
 end loop;
 foreach kind in array array['wheel_random_index(integer)','ensure_daily_wheel_ticket(uuid,date)','credit_pass_boxes(uuid,text,text)'] loop
  if has_function_privilege('authenticated','public.'||kind,'EXECUTE') or has_function_privilege('anon','public.'||kind,'EXECUTE') then raise exception 'Exposed helper %',kind; end if;
 end loop;
 if has_function_privilege('anon','public.spin_daily_wheel(uuid)','EXECUTE') or not has_function_privilege('authenticated','public.spin_daily_wheel(uuid)','EXECUTE') then raise exception 'Bad spin ACL'; end if;
 -- Exhaust both new pools, all rarities: first unlock, duplicate XP, idempotency.
 foreach kind in array array['name','frame'] loop
  execute format('insert into public.%I(profile_id,balance) values($1,1000) on conflict(profile_id) do update set balance=1000',kind||'_box_balances') using target;
  for item in select style,rarity,row_number() over(partition by rarity order by style)-1 as idx from public.box_style_catalog where theme='classic' and (item_kind is null or item_kind=kind) order by rarity,style loop
   rarity_roll:=case item.rarity when 'common' then 0 when 'rare' then 40 when 'epic' then 70 when 'mythic' then 85 else 95 end;
   perform set_config('test.wheel_rarity',rarity_roll::text,true);
   perform set_config('test.wheel_item_index',item.idx::text,true);
   delete from public.box_inventory where profile_id=target and public.box_inventory.kind=test.kind and style=item.style;
   perform set_config('test.wheel_next_rarity','true',true);request:=gen_random_uuid();
   execute format('select public.open_%s_box($1)',kind) into result using request;
   if result->>'kind'<>kind or result->>'style'<>item.style or (result->>'duplicate')::boolean then raise exception 'Wrong % pool/unlock',kind; end if;
   execute format('select public.open_%s_box($1)',kind) into again using request;
   if again<>result then raise exception 'Box retry changed reward'; end if;
   perform set_config('test.wheel_next_rarity','true',true);
   execute format('select public.open_%s_box($1)',kind) into result using gen_random_uuid();
   if not (result->>'duplicate')::boolean or (result->>'xpAwarded')::integer<>(case item.rarity when 'common' then 25 when 'rare' then 50 when 'epic' then 100 when 'mythic' then 250 else 500 end) then raise exception 'Wrong duplicate XP'; end if;
  end loop;
 end loop;
 -- Owner can open the seeded boxes and receives normal owner duplicate XP.
 perform set_config('request.jwt.claim.sub',owner_auth::text,true);
 foreach kind in array array['name','frame'] loop
  perform set_config('test.wheel_rarity','95',true);perform set_config('test.wheel_item_index','0',true);perform set_config('test.wheel_next_rarity','true',true);
  execute format('select public.open_%s_box($1)',kind) into result using gen_random_uuid();
  if not (result->>'duplicate')::boolean or (result->>'xpAwarded')::integer<>500 then raise exception 'Owner box opening failed'; end if;
 end loop;
 if exists(select 1 from pg_temp.wheel_test_draws) then raise exception 'Draws not consumed'; end if;
end;$$;
-- Real authenticated-role call (table access remains blocked).
set local role authenticated;
select public.get_daily_wheel_state();
reset role;
rollback;
