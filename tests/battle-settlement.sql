-- This fixture must never leave its synthetic date or players in the live database.
begin;
-- A separate date and temporary profiles exercise the real admin RPC and triggers.
create or replace function public.battle_today() returns date language sql stable as $$ select date '2070-01-01'; $$;
do $$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid(); d uuid := gen_random_uuid(); e uuid := gen_random_uuid();
  auth_a uuid := gen_random_uuid(); auth_b uuid := gen_random_uuid();
  day date := date '2070-01-01';
  result_row public.daily_battles; payload jsonb; blocked boolean := false;
begin
  insert into public.daily_battle_rounds(day_id) values(day);
  insert into public.public_profiles(id,player_id,username,avatar_color,rank_points) values
    (a,99000001,'btstwin','#3b82f6',100),(b,99000002,'btstloss','#3b82f6',100),
    (c,99000003,'btstfloor','#3b82f6',5),(d,99000004,'btstother','#3b82f6',100),
    (e,99000005,'btstbye','#3b82f6',100);
  insert into public.private_profiles(profile_id,auth_user_id,email) values
    (a,auth_a,'battle-win@example.invalid'),(b,auth_b,'battle-loss@example.invalid');
  insert into public.daily_battles(id,day_id,player_left,player_right) overriding system value values
    (-990001,day,a,b),(-990002,day,c,d),(-990003,day,e,null);
  insert into public.predictions(day_id,slot,title,options,closes_at) values
    (day,0,'Teste resultado principal','[{"id":"1","label":"Sim","rankPoints":96},{"id":"2","label":"Não","rankPoints":81}]',now()-interval '1 hour'),
    (day,1,'Teste ultimo resultado','[{"id":"1","label":"Sim","rankPoints":81},{"id":"2","label":"Não","rankPoints":10}]',now()-interval '1 hour');
  insert into public.picks(profile_id,prediction_day,slot,option_id) values
    (a,day,0,'1'),(b,day,1,'1'),(d,day,0,'1');
  perform set_config('request.jwt.claims',jsonb_build_object('sub',auth_a,'email',(select owner_email from public.app_config where singleton))::text,true);
  perform public.finalize_daily_battle(day);
  if exists(select 1 from public.daily_battles where day_id=day and result<>'open') then raise exception 'Closed before results'; end if;
  perform public.settle_prediction_for_slot(day,0::smallint,'1');
  if exists(select 1 from public.daily_battles where day_id=day and result<>'open') then raise exception 'Closed while extra was pending'; end if;
  payload := public.get_my_daily_battle_with_ranks();
  if payload->>'myResult'<>'open' or payload->>'myRankDelta' is not null then raise exception 'Premature outcome in API'; end if;
  perform public.settle_prediction_for_slot(day,1::smallint,'1');
  select * into result_row from public.daily_battles where id=-990001;
  if result_row.result<>'left' or result_row.left_points<>96 or result_row.right_points<>81
     or result_row.left_rank_delta<>15 or result_row.right_rank_delta<>-15 then raise exception 'Wrong final score or delta: %',row_to_json(result_row); end if;
  if not exists(select 1 from public.public_profiles where id=a and rank_points=211 and battle_wins=1 and battle_losses=0) then raise exception 'Winner award incorrect'; end if;
  if not exists(select 1 from public.public_profiles where id=b and rank_points=166 and battle_losses=1 and battle_wins=0) then raise exception 'Loser deduction incorrect'; end if;
  if not exists(select 1 from public.public_profiles where id=c and rank_points=0 and battle_losses=1) then raise exception 'Zero floor incorrect'; end if;
  if not exists(select 1 from public.daily_battles where id=-990002 and result='right' and left_rank_delta=-5 and right_rank_delta=15) then raise exception 'Actual floor delta incorrect'; end if;
  if not exists(select 1 from public.daily_battles where id=-990003 and result='no_contest' and left_rank_delta=0) then raise exception 'Bye should not award points'; end if;
  payload := public.get_my_daily_battle_with_ranks();
  if payload->>'myResult'<>'win' or (payload->>'myRankDelta')::integer<>15 then raise exception 'Wrong winner perspective'; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',auth_b,'email',(select owner_email from public.app_config where singleton))::text,true);
  payload := public.get_my_daily_battle_with_ranks();
  if payload->>'myResult'<>'loss' or (payload->>'myRankDelta')::integer<>-15 then raise exception 'Wrong loser perspective'; end if;
  perform public.settle_prediction_for_slot(day,1::smallint,'1');
  perform public.finalize_daily_battle(day);
  if not exists(select 1 from public.public_profiles where id=a and rank_points=211 and battle_wins=1) then raise exception 'Duplicate winner award'; end if;
  if not exists(select 1 from public.public_profiles where id=b and rank_points=166 and battle_losses=1) then raise exception 'Duplicate loser deduction'; end if;
  begin
    insert into public.predictions(day_id,slot,title,options,closes_at) values
      (day,2,'Jogo depois do encerramento','[{"id":"1","label":"Sim"},{"id":"2","label":"Não"}]',now());
  exception when raise_exception then
    if sqlerrm not like 'A Batalha do Dia já foi encerrada.%' then raise; end if;
    blocked := true;
  end;
  if not blocked then raise exception 'Allowed publication after finalization'; end if;
end;
$$;
rollback;
