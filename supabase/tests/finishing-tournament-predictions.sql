-- Execute inside a transaction and ROLLBACK. No test picks/results remain.
create temp table tournament_global_before as select
 (select md5(coalesce(jsonb_agg(to_jsonb(p) order by id)::text,'')) from public.public_profiles p) as profiles,
 (select md5(coalesce(jsonb_agg(to_jsonb(p) order by profile_id,prediction_day,slot)::text,'')) from public.picks p) as picks,
 (select md5(coalesce(jsonb_agg(to_jsonb(p) order by day_id,slot)::text,'')) from public.predictions p) as predictions;

do $$
declare tid uuid:='36b34446-4dcf-4d63-8cf3-5ba8ec8d1113';
 uid1 uuid; pid1 uuid; uid2 uuid; pid2 uuid; owner_email text;
 result jsonb; initial_count integer; after_count integer;
begin
 if (select count(*) from public.paid_tournament_predictions where tournament_id=tid)<>21 then raise exception 'Expected 21 tournament predictions'; end if;
 if (select count(*) from (select match_day from public.paid_tournament_predictions where tournament_id=tid group by match_day having count(*)=7) days)<>3 then raise exception 'Expected seven predictions on each of three days'; end if;
 if exists(select 1 from public.paid_tournament_predictions where tournament_id=tid and (match_day not between '2026-10-04' and '2026-10-06' or title<>'Quem terá mais finalizações?' or status<>'open')) then raise exception 'Incorrect published dates, title or status'; end if;
 if has_function_privilege('anon','public.submit_finishing_tournament_pick(uuid,smallint,text)','execute')
  or has_function_privilege('authenticated','public.finishing_tournament_predictions_json(uuid,uuid)','execute')
  or has_table_privilege('authenticated','public.paid_tournament_picks','select')
  or has_table_privilege('authenticated','public.paid_tournament_picks','insert')
  or has_table_privilege('anon','public.paid_tournament_predictions','select') then raise exception 'Tournament data access too broad'; end if;

 select e.profile_id,v.auth_user_id into pid1,uid1 from public.paid_tournament_entries e
 join public.private_profiles v on v.profile_id=e.profile_id where e.tournament_id=tid and v.auth_user_id is not null order by e.registered_at limit 1;
 select p.id,v.auth_user_id into pid2,uid2 from public.public_profiles p join public.private_profiles v on v.profile_id=p.id
 where v.auth_user_id is not null and not exists(select 1 from public.paid_tournament_entries e where e.tournament_id=tid and e.profile_id=p.id) order by p.player_id limit 1;
 select c.owner_email into owner_email from public.app_config c where singleton;
 if uid1 is null or uid2 is null then raise exception 'Missing enrolled/unenrolled test accounts'; end if;
 select count(*) into initial_count from public.paid_tournament_picks;

 perform set_config('request.jwt.claims',jsonb_build_object('sub',uid2,'role','authenticated')::text,true);
 result:=public.get_finishing_tournament(tid);
 if (result->>'enrolled')::boolean or jsonb_array_length(result->'predictions')<>0 then raise exception 'Unenrolled viewer can access tournament picks'; end if;
 begin
  perform public.submit_finishing_tournament_pick(tid,1::smallint,'home'); raise exception 'Unenrolled pick accepted';
 exception when raise_exception then if sqlerrm<>'Inscreva-se no torneio para palpitar.' then raise; end if; end;
 begin
  perform public.settle_finishing_tournament_prediction(tid,1::smallint,10,5); raise exception 'Non-admin settlement accepted';
 exception when raise_exception then if sqlerrm<>'Somente o proprietário pode concluir os palpites do torneio.' then raise; end if; end;
 begin
  perform public.get_admin_finishing_tournament(tid); raise exception 'Non-admin result list accepted';
 exception when raise_exception then if sqlerrm<>'Somente o proprietário pode acessar a administração.' then raise; end if; end;

 perform set_config('request.jwt.claims',jsonb_build_object('sub',uid1,'role','authenticated')::text,true);
 result:=public.get_finishing_tournament(tid);
 if jsonb_array_length(result->'predictions')<>21 then raise exception 'Enrolled viewer does not see all predictions'; end if;
 begin
  perform public.submit_finishing_tournament_pick(tid,1::smallint,'invalid'); raise exception 'Invalid option accepted';
 exception when raise_exception then if sqlerrm<>'Escolha Casa, Empate ou Fora.' then raise; end if; end;
 result:=public.submit_finishing_tournament_pick(tid,1::smallint,'home');
 result:=public.submit_finishing_tournament_pick(tid,1::smallint,'home');
 if (select count(*) from public.paid_tournament_picks)<>initial_count+1 or result->'predictions'->0->>'myOptionId'<>'home' then raise exception 'Duplicate retry or own response missing'; end if;
 begin
  perform public.submit_finishing_tournament_pick(tid,1::smallint,'away'); raise exception 'Confirmed response changed';
 exception when raise_exception then if sqlerrm<>'Você já confirmou seu palpite nesta partida.' then raise; end if; end;
 perform public.submit_finishing_tournament_pick(tid,2::smallint,'draw');
 perform public.submit_finishing_tournament_pick(tid,3::smallint,'away');

 -- Only test transaction: enroll a second fixture account and submit a losing response.
 insert into public.paid_tournament_entries(tournament_id,profile_id,registration_source) values(tid,pid2,'admin');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',uid2,'role','authenticated')::text,true);
 result:=public.get_finishing_tournament(tid);
 if result->'predictions'->0->>'myOptionId' is not null then raise exception 'Other player response leaked'; end if;
 perform public.submit_finishing_tournament_pick(tid,1::smallint,'away');

 -- Expire fixture deadlines to exercise the real server-side gate and settlement.
 update public.paid_tournament_predictions set closes_at=clock_timestamp()-interval '2 hours',match_day=((clock_timestamp()-interval '2 hours') at time zone 'America/Sao_Paulo')::date
 where tournament_id=tid and slot<=4;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',uid1,'role','authenticated')::text,true);
 begin
  perform public.submit_finishing_tournament_pick(tid,4::smallint,'home'); raise exception 'Late pick accepted';
 exception when raise_exception then if sqlerrm<>'O prazo para palpitar terminou.' then raise; end if; end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',uid1,'email',owner_email,'role','authenticated')::text,true);
 begin
  perform public.settle_finishing_tournament_prediction(tid,5::smallint,10,5); raise exception 'Future match settlement accepted';
 exception when raise_exception then if sqlerrm<>'A partida ainda não começou.' then raise; end if; end;
 perform public.settle_finishing_tournament_prediction(tid,1::smallint,12,8);
 perform public.settle_finishing_tournament_prediction(tid,2::smallint,9,9);
 perform public.settle_finishing_tournament_prediction(tid,3::smallint,7,11);
 perform public.settle_finishing_tournament_prediction(tid,1::smallint,12,8);
 if (select correct_answers from public.paid_tournament_entries where tournament_id=tid and profile_id=pid1)<>3
  or (select correct_answers from public.paid_tournament_entries where tournament_id=tid and profile_id=pid2)<>0 then raise exception 'Incorrect tournament score or duplicate settlement'; end if;
 begin
  perform public.settle_finishing_tournament_prediction(tid,1::smallint,8,12); raise exception 'Confirmed result changed';
 exception when raise_exception then if sqlerrm<>'Este resultado já foi confirmado.' then raise; end if; end;
 result:=public.get_finishing_tournament(tid);
 if result->'ownRank'->>'correctAnswers'<>'3' or result->'predictions'->0->>'myResult'<>'correct' then raise exception 'Ranking/result not updated'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',uid2,'role','authenticated')::text,true);
 result:=public.get_finishing_tournament(tid);
 if result->'predictions'->0->>'myResult'<>'incorrect' then raise exception 'Losing response not classified'; end if;

 select count(*) into after_count from public.paid_tournament_picks;
 if after_count<>initial_count+4 then raise exception 'Unexpected tournament pick count'; end if;
 if (select profiles from tournament_global_before) is distinct from (select md5(coalesce(jsonb_agg(to_jsonb(p) order by id)::text,'')) from public.public_profiles p)
  or (select picks from tournament_global_before) is distinct from (select md5(coalesce(jsonb_agg(to_jsonb(p) order by profile_id,prediction_day,slot)::text,'')) from public.picks p)
  or (select predictions from tournament_global_before) is distinct from (select md5(coalesce(jsonb_agg(to_jsonb(p) order by day_id,slot)::text,'')) from public.predictions p) then
  raise exception 'Tournament mutated global profile stats, picks or predictions';
 end if;
end;
$$;
