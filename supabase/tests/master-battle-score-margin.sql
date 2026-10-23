-- Synthetic players/dates only. This script must always finish with ROLLBACK.
begin;
create temporary table margin_real_profiles as select id,to_jsonb(p) data from public.public_profiles p;
create temporary table margin_real_battles as select id,to_jsonb(b) data from public.daily_battles b;
-- Exclude Arena enrollment/awards from a test of Confronto do Dia settlement.
alter table public.predictions disable trigger arena_prediction_changed;
alter table public.picks disable trigger arena_picks_inserted;
alter table public.picks disable trigger arena_picks_updated;
alter table public.picks disable trigger battle_new_pick;
alter table public.public_profiles disable trigger battle_new_profile;
alter table public.daily_battle_rounds disable trigger prune_battles_after_round_creation;
create or replace function public.battle_today() returns date language sql stable as $$select date '2075-01-01'$$;
create temporary table margin_cases(
 id int primary key,left_id uuid default gen_random_uuid(),right_id uuid default gen_random_uuid(),
 left_start int,right_start int,left_score int,right_score int,left_base int,right_base int,
 expected_bonus int,expected_outcome text,battle_id bigint,day_id date default date '2075-01-01'
);
insert into margin_cases(id,left_start,right_start,left_score,right_score,left_base,right_base,expected_bonus,expected_outcome) values
 (1,2200,2300,130,100,2200,2300,30,'left'),
 (2,1900,2200,20,100,1900,2200,80,'right'),
 (3,1900,2100,130,100,1900,2100,30,'left'),
 (4,2100,2100,100,100,2100,2100,0,'draw'),
 (5,2099,2099,130,100,2099,2099,15,'left'),
 (6,1700,1900,130,100,1700,1900,25,'left'),
 (7,1900,1700,130,100,1900,1700,15,'left'),
 (8,2099,2099,130,100,2200,2099,15,'left'),
 (9,2100,1900,20,100,2000,1900,80,'right'),
 (10,5,2200,20,100,5,2200,80,'right'),
 (11,2300,2200,100,130,2300,2200,30,'right'),
 (12,2200,null,130,0,2200,null,0,'no_contest'),
 (13,1900,2200,130,100,1900,2200,25,'left');
update margin_cases set day_id=date '2000-01-01' where id=13;

do $$ declare fixture record;begin
 for fixture in select * from margin_cases loop
  insert into public.public_profiles(id,player_id,username,avatar_color,rank_points) values
   (fixture.left_id,99062000+fixture.id*2,'marginl'||fixture.id,'#3b82f6',fixture.left_start);
  if fixture.right_start is not null then
   insert into public.public_profiles(id,player_id,username,avatar_color,rank_points) values
    (fixture.right_id,99062001+fixture.id*2,'marginr'||fixture.id,'#3b82f6',fixture.right_start);
  end if;
  insert into public.daily_battle_rounds(day_id) values(fixture.day_id) on conflict do nothing;
  insert into public.daily_battles(day_id,player_left,player_right) values
   (fixture.day_id,fixture.left_id,case when fixture.right_start is not null then fixture.right_id end);
  update margin_cases set battle_id=(select id from public.daily_battles where day_id=fixture.day_id and player_left=fixture.left_id) where id=fixture.id;
  update public.public_profiles set rank_points=fixture.left_base where id=fixture.left_id;
  update public.public_profiles set rank_points=fixture.right_base where id=fixture.right_id;
 end loop;
 -- Every player gets their own market so scores come from valid options.
 for fixture in select * from margin_cases loop
  -- Only ten published slots per day are supported: the shared options contain
  -- every score exercised by these independent matchup fixtures.
  insert into public.predictions(day_id,slot,title,options,closes_at,status)
   select fixture.day_id,slot::smallint,'Master margin QA',
    '[{"id":"130","label":"130","rankPoints":130},{"id":"100","label":"100","rankPoints":100},{"id":"20","label":"20","rankPoints":20},{"id":"0","label":"0","rankPoints":0}]'::jsonb,
    now()-interval '1 hour','open' from generate_series(0,1) slot on conflict(day_id,slot) do nothing;
  insert into public.picks(profile_id,prediction_day,slot,option_id,status) values
   (fixture.left_id,fixture.day_id,0,fixture.left_score::text,'green');
  if fixture.right_start is not null then
   insert into public.picks(profile_id,prediction_day,slot,option_id,status) values
    (fixture.right_id,fixture.day_id,1,fixture.right_score::text,'green');
  end if;
 end loop;
 perform public.finalize_daily_battle(date '2075-01-01');
 if exists(select 1 from margin_cases c join public.daily_battles b on b.id=c.battle_id where b.result<>'open') then raise exception 'Battle finalized before last result';end if;
 update public.predictions set status='settled',winning_option_id='130',settled_at=now() where day_id in(date '2075-01-01',date '2000-01-01') and slot=0;
 if exists(select 1 from margin_cases c join public.daily_battles b on b.id=c.battle_id where b.result<>'open') then raise exception 'Battle finalized with pending extra';end if;
 update public.predictions set status='settled',winning_option_id='100',settled_at=now() where day_id in(date '2075-01-01',date '2000-01-01') and slot=1;
end $$;

create function pg_temp.assert_margin_case(p_id int,p_outcome text,p_bonus int) returns void language plpgsql as $$
declare c margin_cases;b public.daily_battles;ld int;rd int;begin
 select * into strict c from margin_cases where id=p_id;
 select * into strict b from public.daily_battles where id=c.battle_id;
 ld:=greatest(0,c.left_base+case p_outcome when 'left' then p_bonus when 'right' then -p_bonus else 0 end)-c.left_base;
 rd:=case when c.right_start is not null then greatest(0,c.right_base+case p_outcome when 'right' then p_bonus when 'left' then -p_bonus else 0 end)-c.right_base else 0 end;
 if b.result<>p_outcome or b.left_rank_delta<>ld or b.right_rank_delta<>rd then raise exception 'Wrong case % deltas/result: %',p_id,to_jsonb(b);end if;
 if not exists(select 1 from public.public_profiles where id=c.left_id and rank_points=c.left_base+ld
  and battle_wins=(p_outcome='left')::int and battle_losses=(p_outcome='right')::int and battle_draws=(p_outcome='draw')::int) then raise exception 'Wrong left balance/counters for case %',p_id;end if;
 if c.right_start is not null and not exists(select 1 from public.public_profiles where id=c.right_id and rank_points=c.right_base+rd
  and battle_wins=(p_outcome='right')::int and battle_losses=(p_outcome='left')::int and battle_draws=(p_outcome='draw')::int) then raise exception 'Wrong right balance/counters for case %',p_id;end if;
end $$;

do $$ declare c record;begin
 for c in select * from margin_cases loop
  perform pg_temp.assert_margin_case(c.id,c.expected_outcome,c.expected_bonus);
 end loop;
 perform public.finalize_daily_battle(date '2075-01-01');
 for c in select * from margin_cases loop
  perform pg_temp.assert_margin_case(c.id,c.expected_outcome,c.expected_bonus);
 end loop;
 if has_function_privilege('anon','public.battle_points_transfer(date,integer,integer,text,integer,integer)','execute')
  or has_function_privilege('authenticated','public.battle_points_transfer(date,integer,integer,text,integer,integer)','execute') then raise exception 'Private reward helper exposed';end if;
end $$;

-- Preserve real serialized result payloads for UI validation of both examples.
create temporary table margin_initial_api as select c.id,public.profile_daily_battle(c.left_id,c.day_id) left_view,public.profile_daily_battle(c.right_id,c.day_id) right_view from margin_cases c where id in(1,2,3);
do $$ declare target uuid;begin
 select right_id into target from margin_cases where id=1;
 update public.picks set option_id='20' where profile_id=target and prediction_day=date '2075-01-01';
 perform pg_temp.assert_margin_case(1,'left',110);
 update public.picks set option_id='20' where profile_id=target and prediction_day=date '2075-01-01';
 perform pg_temp.assert_margin_case(1,'left',110);
 update public.picks set status='red' where profile_id=target and prediction_day=date '2075-01-01';
 perform pg_temp.assert_margin_case(1,'left',130);
 update public.picks set status='red' where profile_id=(select left_id from margin_cases where id=1) and prediction_day=date '2075-01-01';
 perform pg_temp.assert_margin_case(1,'draw',0);
 update public.picks set status='green' where profile_id=target and prediction_day=date '2075-01-01';
 perform pg_temp.assert_margin_case(1,'right',20);
 update public.picks set status='green' where profile_id=(select left_id from margin_cases where id=1) and prediction_day=date '2075-01-01';
 perform pg_temp.assert_margin_case(1,'left',110);
 if exists(select 1 from margin_real_profiles old left join public.public_profiles p on p.id=old.id where p.id is null or to_jsonb(p)<>old.data)
  or exists(select 1 from margin_real_battles old left join public.daily_battles b on b.id=old.id where b.id is null or to_jsonb(b)<>old.data) then raise exception 'Real players/battles changed';end if;
end $$;
select jsonb_build_object('result','PASS: 13 cases; exact examples; either-side Mestre; 2099/2100 boundary; captured ranks; normal upset reward; historical reward; floor; draw; no opponent; last-result gate; repeat safe; same-winner corrections; reversed winner; real data unchanged; ACL preserved; all rolled back',
 'initialPayloads',(select jsonb_agg(to_jsonb(p) order by id) from margin_initial_api p),
 'correctedPayload',public.profile_daily_battle((select left_id from margin_cases where id=1),date '2075-01-01')) verification;
rollback;
