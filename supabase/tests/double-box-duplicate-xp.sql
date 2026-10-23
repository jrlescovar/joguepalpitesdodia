-- Run after the migration in a transaction ending with ROLLBACK.
create temporary table double_box_real_profiles as select id,to_jsonb(p) as data from public.public_profiles p;
create temporary table double_box_historical_openings as select id,to_jsonb(o) as data from public.box_openings o;
create temporary table double_box_drop_function as select pg_get_functiondef('public.interact_level_drop(uuid,uuid,boolean)'::regprocedure) as definition;
insert into public.public_profiles(id,player_id,username,avatar_color)
values ('dddddd60-0000-4000-8000-000000000001',9906001,'boxxpqa1','#22c55e'),
 ('dddddd60-0000-4000-8000-000000000002',9906002,'boxxpqa2','#22c55e');
insert into public.pass_prepaid(profile_id,ends_at) values ('dddddd60-0000-4000-8000-000000000002',now()+interval '30 days');
create or replace function public.own_profile_id() returns uuid language sql stable as $$select current_setting('test.double_box_profile')::uuid;$$;
create or replace function public.box_random_index(p_count integer) returns integer language plpgsql volatile as $$
begin
 if current_setting('test.double_box_first',true)='true' then
  perform set_config('test.double_box_first','false',true);
  return current_setting('test.double_box_roll')::integer;
 end if;
 return 0;
end;
$$;
do $$
declare test_profile_id uuid; tier record; route text; balance_table text; roll integer;
 request uuid; opened jsonb; replay jsonb; xp_before bigint; xp_after bigint; expected integer;
 balance_before integer; balance_after integer; opening_count integer:=0;
begin
 foreach test_profile_id in array array['dddddd60-0000-4000-8000-000000000001'::uuid,'dddddd60-0000-4000-8000-000000000002'::uuid] loop
  perform set_config('test.double_box_profile',test_profile_id::text,true);
  foreach route in array array['open_box','open_name_box','open_frame_box','open_halloween_box','open_font_box'] loop
   balance_table:=case route when 'open_box' then 'box_balances' when 'open_name_box' then 'name_box_balances' when 'open_frame_box' then 'frame_box_balances' when 'open_halloween_box' then 'halloween_box_balances' else 'font_box_balances' end;
   execute format('insert into public.%I(profile_id,balance) values($1,100) on conflict(profile_id) do update set balance=100',balance_table) using test_profile_id;
   for tier in select * from (values ('common',50,0),('rare',100,40),('epic',200,70),('mythic',500,85),('legendary',1000,95)) t(rarity,base_xp,classic_roll) loop
    if (route<>'open_halloween_box' or tier.rarity in ('epic','mythic','legendary')) and (route<>'open_font_box' or tier.rarity<>'common') then
     roll:=case route when 'open_halloween_box' then case tier.rarity when 'epic' then 0 when 'mythic' then 60 else 90 end when 'open_font_box' then case tier.rarity when 'rare' then 0 when 'epic' then 45 when 'mythic' then 80 else 95 end else tier.classic_roll end;
     -- A genuinely new item unlocks with zero XP.
     delete from public.box_inventory where profile_id=test_profile_id;
     select public.total_xp(level,xp) into xp_before from public.public_profiles where id=test_profile_id;
     perform set_config('test.double_box_roll',roll::text,true);
     perform set_config('test.double_box_first','true',true);
     execute format('select public.%I($1)',route) into opened using gen_random_uuid();
     if opened->>'rarity'<>tier.rarity or (opened->>'duplicate')::boolean or (opened->>'xpAwarded')::int<>0 then raise exception 'New item failed in % %: %',route,tier.rarity,opened; end if;
     if not exists(select 1 from public.box_inventory where profile_id=test_profile_id and kind=opened->>'kind' and style=opened->>'style') then raise exception 'New item not saved'; end if;
     select public.total_xp(level,xp) into xp_after from public.public_profiles where id=test_profile_id;
     if xp_after<>xp_before then raise exception 'New item awarded XP'; end if;
     -- Repeat exactly the same roll: doubled base, then supporter 1.5x.
     expected:=case when test_profile_id='dddddd60-0000-4000-8000-000000000002'::uuid then tier.base_xp*3/2 else tier.base_xp end;
     execute format('select balance from public.%I where profile_id=$1',balance_table) into balance_before using test_profile_id;
     request:=gen_random_uuid();
     perform set_config('test.double_box_first','true',true);
     execute format('select public.%I($1)',route) into opened using request;
     if not (opened->>'duplicate')::boolean or (opened->>'xpAwarded')::int<>expected then raise exception 'Duplicate XP failed in % %: expected %, got %',route,tier.rarity,expected,opened; end if;
     select public.total_xp(level,xp) into xp_after from public.public_profiles where id=test_profile_id;
     if xp_after-xp_before<>expected then raise exception 'Persisted XP did not match response'; end if;
     execute format('select public.%I($1)',route) into replay using request;
     if replay<>opened then raise exception 'Retry response changed'; end if;
     if not exists(select 1 from public.public_profiles where id=test_profile_id and public.total_xp(level,xp)=xp_after) then raise exception 'Retry awarded extra XP'; end if;
     execute format('select balance from public.%I where profile_id=$1',balance_table) into balance_after using test_profile_id;
     if balance_after<>balance_before-1 then raise exception 'Duplicate/retry consumed wrong box quantity'; end if;
     if has_function_privilege('anon','public.'||route||'(uuid)','EXECUTE') or not has_function_privilege('authenticated','public.'||route||'(uuid)','EXECUTE') then raise exception 'Box permissions changed'; end if;
     opening_count:=opening_count+1;
    end if;
   end loop;
  end loop;
 end loop;
 if opening_count<>44 then raise exception 'Not all 44 box/rarity/supporter combinations tested: %',opening_count; end if;
 if exists(select 1 from double_box_real_profiles s join public.public_profiles p using(id) where s.data<>to_jsonb(p)) then raise exception 'Real player stats changed'; end if;
 if exists(select 1 from double_box_historical_openings s join public.box_openings o using(id) where s.data<>to_jsonb(o)) then raise exception 'Historical opening changed'; end if;
 if (select definition from double_box_drop_function)<>pg_get_functiondef('public.interact_level_drop(uuid,uuid,boolean)'::regprocedure) then raise exception 'Drop XP changed'; end if;
end;
$$;
select 'PASS: 44 duplicate cases across all 5 boxes/rarities; supporter 1.5x; actual XP; new unlocks; idempotency; balances; permissions; historical and drop rewards preserved' as result;


