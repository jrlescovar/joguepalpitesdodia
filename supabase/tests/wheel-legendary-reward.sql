-- All test writes, temporary function overrides and earned rewards roll back.
begin;
set local statement_timeout='30s';
create temporary table wheel_test_cases(result text);
create temporary table wheel_existing_spins as select spin_id,result from public.daily_wheel_spins;
create temporary table wheel_existing_passes as select profile_id,to_jsonb(p) data from public.pass_prepaid p;
alter table public.public_profiles disable trigger user;
create or replace function public.own_profile_id() returns uuid language sql stable as $$select nullif(current_setting('wheel.test_profile',true),'')::uuid$$;
do $$
declare prize record;offset_weight int:=0;weekday int;hits int;
begin
 if exists(select 1 from public.daily_wheel_prizes where kind='supporter') then raise exception 'Supporter still in catalog';end if;
 if (select sum(weight) from public.daily_wheel_prizes)<>24000 or (select weight from public.daily_wheel_prizes where kind='legendary')<>1200 then raise exception 'Legendary chance is not exactly 5 percent';end if;
 for weekday in 0..6 loop
  offset_weight:=0;
  for prize in select * from public.daily_wheel_prizes
   where kind<>'legendary' or extract(dow from date '2026-10-19'+weekday)=4 order by position loop
   if public.wheel_prize_position(date '2026-10-19'+weekday,offset_weight)<>prize.position
    or public.wheel_prize_position(date '2026-10-19'+weekday,offset_weight+prize.weight-1)<>prize.position then raise exception 'Incorrect prize boundary/day';end if;
   offset_weight:=offset_weight+prize.weight;
  end loop;
  select count(*) into hits from generate_series(0,offset_weight-1)r where public.wheel_prize_position(date '2026-10-19'+weekday,r)=8;
  if hits<>(case when weekday=3 then 1200 else 0 end) then raise exception 'Legendary draw must be 5 percent on Thursday and zero otherwise';end if;
 end loop;
 insert into wheel_test_cases values('All integer outcomes verified for all seven weekdays: 1200/24000 on Thursday, zero legendary outcomes otherwise');
end $$;
-- Force only the random result; exercise the real transactional award code.
create or replace function public.wheel_prize_position(p_day date,p_roll integer default null) returns integer language sql volatile security definer set search_path=public,pg_temp as $$select 8$$;
do $$
declare target uuid; request_id uuid; earned jsonb;opened jsonb;state jsonb;drop_id uuid;refused boolean;fixture int;before_passes jsonb;legacy jsonb;
begin
 for fixture in 1..2 loop
  target:=gen_random_uuid();request_id:=gen_random_uuid();
  insert into public.public_profiles(id,player_id,username,avatar_color) values(target,99133000+fixture,'wheelbox'||fixture,'#3b82f6');
  perform set_config('wheel.test_profile',target::text,true);
  if fixture=2 then insert into public.pass_prepaid(profile_id,ends_at) values(target,now()+interval '1 month');end if;
  select to_jsonb(p) into before_passes from public.pass_prepaid p where profile_id=target;
  refused:=false;begin perform public.spin_daily_wheel(request_id);exception when others then refused:=true;end;
  if not refused then raise exception 'Ineligible player could spin';end if;
  insert into public.daily_wheel_tickets(profile_id,day_id) values(target,(now() at time zone 'America/Sao_Paulo')::date);
  earned:=public.spin_daily_wheel(request_id);
  if earned->>'kind'<>'legendary' or earned->'boxes'<>'{"legendary":1}'::jsonb or (earned->>'replacement')::boolean then raise exception 'Incorrect legendary reward payload';end if;
  if public.spin_daily_wheel(request_id) is distinct from earned then raise exception 'Spin replay changed';end if;
  if (select count(*) from public.level_drops where profile_id=target and drop_kind='legendary' and status='ready' and received_at is not null)<>1 then raise exception 'Did not award exactly one ready box';end if;
  if (select to_jsonb(p) from public.pass_prepaid p where profile_id=target) is distinct from before_passes then raise exception 'Supporter entitlement changed';end if;
  if exists(select 1 from public.pass_box_rewards where profile_id=target) or exists(select 1 from public.box_balances where profile_id=target and balance>0) or exists(select 1 from public.font_box_balances where profile_id=target and balance>0) then raise exception 'Unrequested pass boxes credited';end if;
  refused:=false;begin perform public.spin_daily_wheel(gen_random_uuid());exception when others then refused:=true;end;
  if not refused or (select count(*) from public.level_drops where profile_id=target)<>1 then raise exception 'Daily limit or award idempotence broken';end if;
  state:=public.get_level_drops();drop_id:=(state#>>'{drops,0,id}')::uuid;
  opened:=public.interact_level_drop(drop_id,gen_random_uuid(),true);
  if opened->>'status'<>'claimed' or opened#>>'{reward,rarity}'<>'legendary' then raise exception 'Won box cannot be opened as legendary';end if;
  if public.interact_level_drop(drop_id,gen_random_uuid(),true) is distinct from opened then raise exception 'Opening replay changed';end if;
  if (select count(*) from public.box_openings b where b.profile_id=target and b.request_id=drop_id)<>1 then raise exception 'Duplicate box opening';end if;
  insert into wheel_test_cases values(case when fixture=1 then 'Non-supporter: one ready legendary box, no pass/other box credits, replay safe, daily limit, actual legendary opening' else 'Existing supporter: same legendary box, no random replacement, existing entitlement preserved' end);
 end loop;
 -- A previously stored supporter result remains an immutable receipt.
 legacy:=jsonb_build_object('dayId','2000-01-01','position',8,'kind','supporter','label','Apoiador por 1 mês','boxes',jsonb_build_object('classic',7,'font',1));
 request_id:=gen_random_uuid();
 insert into public.daily_wheel_tickets(profile_id,day_id) values(target,date '2000-01-01');
 insert into public.daily_wheel_spins(profile_id,day_id,request_id,result) values(target,date '2000-01-01',request_id,legacy);
 if public.spin_daily_wheel(request_id) is distinct from legacy then raise exception 'Historical supporter receipt altered';end if;
 if exists(select 1 from wheel_existing_spins old left join public.daily_wheel_spins s using(spin_id) where s.result is distinct from old.result) then raise exception 'Existing spin modified';end if;
 if exists(select 1 from wheel_existing_passes old left join public.pass_prepaid p using(profile_id) where to_jsonb(p) is distinct from old.data) then raise exception 'Existing pass modified';end if;
 if has_function_privilege('anon','public.spin_daily_wheel(uuid)','execute') or has_function_privilege('authenticated','public.wheel_prize_position(date,integer)','execute') then raise exception 'Permissions leaked';end if;
 insert into wheel_test_cases values('Historical supporter receipts and existing entitlements preserved; internal draw remains private');
end $$;
select jsonb_agg(result) passed from wheel_test_cases;
rollback;
