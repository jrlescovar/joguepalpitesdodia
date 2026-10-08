-- Isolated fixtures; execute together with migration in a rolled-back transaction.
create temporary table bot_real_profiles as select id,to_jsonb(p) as data from public.public_profiles p;
create temporary table bot_real_picks as select profile_id,prediction_day,slot,to_jsonb(p) as data from public.picks p;
create or replace function public.battle_today() returns date language sql stable as $$select '2099-10-08'::date;$$;
delete from public.daily_bot_accounts;
update public.daily_bot_settings set enabled=false where singleton;
insert into public.public_profiles(id,player_id,username,avatar_color,level,xp,daily_streak_current,last_played_prediction)
values ('11111111-1111-4111-8111-111111111111',9900001,'botqatest1','#3b82f6',1,10,3,'2099-10-07'),
 ('22222222-2222-4222-8222-222222222222',9900002,'botqatest2','#22c55e',1,0,0,null),
 ('33333333-3333-4333-8333-333333333333',9900003,'botqahuman','#ec4899',1,0,0,null);
insert into public.pass_prepaid(profile_id,ends_at) values('22222222-2222-4222-8222-222222222222',now()+interval '1 day');
insert into public.predictions(day_id,slot,title,options,closes_at,status)
select '2099-10-08',n,'Teste isolado de bots',
 '[{"id":"a","label":"Casa","rankPoints":5},{"id":"b","label":"Fora","rankPoints":15}]'::jsonb,
 case when n=2 then now()-interval '1 hour' else now()+interval '1 day' end,
 case when n=3 then 'settled' else 'open' end from generate_series(0,3) n;
insert into public.predictions(day_id,slot,title,options,closes_at)
values('2099-10-09',0,'Palpite de outra data','[{"id":"a","label":"Casa"},{"id":"b","label":"Fora"}]',now()+interval '1 day');
insert into public.picks(profile_id,prediction_day,slot,option_id)
values('11111111-1111-4111-8111-111111111111','2099-10-08',1,'b');
select set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'email',
 (select owner_email from public.app_config where singleton))::text,true);

do $$
declare state jsonb; rejected boolean:=false;
begin
  perform public.admin_add_daily_bot('11111111-1111-4111-8111-111111111111');
  perform public.admin_add_daily_bot('22222222-2222-4222-8222-222222222222');
  if public.run_daily_bot_picks()<>0 then raise exception 'Paused bots created picks'; end if;
  state:=public.admin_set_daily_bots_enabled(true);
  if not (state->>'ready')::boolean or not (state->>'enabled')::boolean then raise exception 'Activation failed'; end if;
  if (select count(*) from public.daily_bot_pick_log)<>3 then raise exception 'Wrong number of new picks'; end if;
  if (select option_id from public.picks where profile_id='11111111-1111-4111-8111-111111111111' and prediction_day='2099-10-08' and slot=1)<>'b' then raise exception 'Confirmed pick changed'; end if;
  if exists(select 1 from public.picks where prediction_day in ('2099-10-08','2099-10-09')
    and (slot in (2,3) or prediction_day='2099-10-09' or profile_id='33333333-3333-4333-8333-333333333333')) then
    raise exception 'Expired, settled, future-day or unselected account received picks';
  end if;
  if exists(select 1 from public.daily_bot_pick_log l join public.picks p using(profile_id,prediction_day,slot)
    where p.option_id not in ('a','b')) then raise exception 'Invalid option selected'; end if;
  if not exists(select 1 from public.public_profiles where id='11111111-1111-4111-8111-111111111111'
    and level=2 and xp=0 and daily_streak_current=4 and last_played_prediction='2099-10-08') then raise exception 'Normal XP/streak incorrect'; end if;
  if not exists(select 1 from public.public_profiles where id='22222222-2222-4222-8222-222222222222'
    and level=2 and xp=1 and daily_streak_current=1) then raise exception 'Supporter XP/streak incorrect'; end if;
  if public.run_daily_bot_picks()<>0 or (select count(*) from public.daily_bot_pick_log)<>3 then raise exception 'Duplicate picks or XP'; end if;
  perform public.admin_set_daily_bots_enabled(false);
  insert into public.predictions(day_id,slot,title,options,closes_at)
    values('2099-10-08',5,'Novo palpite publicado','[{"id":"a","label":"Casa"},{"id":"b","label":"Fora"}]',now()+interval '1 day');
  if public.run_daily_bot_picks()<>0 then raise exception 'Pause did not stop new picks'; end if;
  perform public.admin_set_daily_bots_enabled(true);
  if (select count(*) from public.daily_bot_pick_log)<>5 then raise exception 'Newly published pick ignored'; end if;
  perform public.admin_remove_daily_bot('22222222-2222-4222-8222-222222222222');
  insert into public.predictions(day_id,slot,title,options,closes_at)
    values('2099-10-08',6,'Mais um palpite publicado','[{"id":"a","label":"Casa"},{"id":"b","label":"Fora"}]',now()+interval '1 day');
  if public.run_daily_bot_picks()<>1 then raise exception 'Removed account still receives new picks'; end if;
  if (select count(*) from public.picks where profile_id='22222222-2222-4222-8222-222222222222' and prediction_day='2099-10-08')<>3 then raise exception 'Removing bot erased picks'; end if;
  begin perform public.admin_set_daily_bots_enabled(null); exception when others then rejected:=true; end;
  if not rejected then raise exception 'Null activation accepted'; end if;
end;
$$;
select public.admin_add_daily_bot('33333333-3333-4333-8333-333333333333');
do $$
begin
  if (select count(*) from public.picks where profile_id='33333333-3333-4333-8333-333333333333' and prediction_day='2099-10-08')<>4 then
    raise exception 'Account added while enabled did not receive current open picks';
  end if;
end;
$$;
create or replace function public.battle_today() returns date language sql stable as $$select '2099-10-09'::date;$$;
do $$
begin
  if public.run_daily_bot_picks()<>2 then raise exception 'Bots did not follow next calendar day'; end if;
  if not exists(select 1 from public.public_profiles where id='11111111-1111-4111-8111-111111111111'
    and daily_streak_current=5 and last_played_prediction='2099-10-09') then raise exception 'Next-day streak incorrect'; end if;
end;
$$;
select set_config('request.jwt.claims','{"email":"ordinary@example.test"}',true);
do $$
declare denied integer:=0;
begin
  begin perform public.admin_set_daily_bots_enabled(true); exception when others then denied:=denied+1; end;
  begin perform public.admin_add_daily_bot('33333333-3333-4333-8333-333333333333'); exception when others then denied:=denied+1; end;
  begin perform public.admin_remove_daily_bot('11111111-1111-4111-8111-111111111111'); exception when others then denied:=denied+1; end;
  begin perform public.get_admin_daily_bots(); exception when others then denied:=denied+1; end;
  if denied<>4 or has_function_privilege('authenticated','public.run_daily_bot_picks()','EXECUTE')
     or has_table_privilege('authenticated','public.daily_bot_pick_log','SELECT') then raise exception 'Bot security failed'; end if;
  if exists(select 1 from bot_real_profiles b left join public.public_profiles p using(id) where b.data is distinct from to_jsonb(p))
     or exists(select 1 from bot_real_picks b left join public.picks p using(profile_id,prediction_day,slot) where b.data is distinct from to_jsonb(p)) then
    raise exception 'Unrelated real account data changed';
  end if;
  if not exists(select 1 from cron.job where jobname='daily-bot-picks' and active and schedule='* * * * *') then raise exception 'Daily scheduler missing'; end if;
end;
$$;
select 'PASS bots: activation/pause/removal/new games; no expired/duplicate picks; normal/premium XP; admin-only; real accounts unchanged' as result;
