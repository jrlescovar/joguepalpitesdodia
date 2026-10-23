begin;
-- Real RPC checks with throwaway players. The enclosing transaction always rolls back.
do $$
declare tid uuid:='2e0617ac-f47a-4abd-aae8-68b4c59aa12d'; player uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid(); subject uuid:=gen_random_uuid(); other_subject uuid:=gen_random_uuid(); admin_subject uuid;
 response jsonb; original_profile jsonb; denied boolean; order_row public.infinitepay_orders; qa_target jsonb; evidence jsonb;
begin
 if (select count(*) from public.paid_tournament_predictions where tournament_id=tid)<>18 then raise exception 'Missing fixtures';end if;
 if (select count(distinct home_team||' x '||away_team) from public.paid_tournament_predictions where tournament_id=tid)<>18 then raise exception 'Duplicate fixtures';end if;
 if (select count(*) from public.paid_tournament_predictions where tournament_id=tid and match_day='2026-10-13')<>9 or (select count(*) from public.paid_tournament_predictions where tournament_id=tid and match_day='2026-10-14')<>9 then raise exception 'Incorrect matchdays';end if;
 if exists(select 1 from public.paid_tournament_predictions where tournament_id=tid and closes_at<(select starts_at from public.paid_tournaments where id=tid)) then raise exception 'Game closes before registration';end if;
 insert into public.public_profiles(id,player_id,username,avatar_color) values(player,9900601,'championsqa1','#3b82f6'),(outsider,9900602,'championsqa2','#3b82f6');
 insert into public.private_profiles(profile_id,auth_user_id,email) values(player,subject,'championsqa1@example.invalid'),(outsider,other_subject,'championsqa2@example.invalid');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other_subject,'role','authenticated')::text,true);
 response:=public.get_finishing_tournament(tid);
 if response->>'metric'<>'classic' or response->>'entryCents'<>'333' or response->>'predictionCount'<>'18' or response->>'registrationOpen'<>'true' or jsonb_array_length(response->'matchDays')<>2 or response->'predictions'<>'[]'::jsonb then raise exception 'Incorrect registration state';end if;
 if jsonb_array_length(response->'availableTournaments')<>2 then raise exception 'Old tournament lost';end if;
 denied:=false;begin perform public.submit_finishing_tournament_pick(tid,1::smallint,'home');exception when others then if sqlerrm like '%Inscreva-se%' then denied:=true;else raise;end if;end;
 if not denied then raise exception 'Unenrolled player could pick';end if;
 -- Checkout reserves the exact existing price, with no fabricated payment.
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 order_row:=public.reserve_tournament_order(outsider,gen_random_uuid(),'champions-qa',tid);
 if order_row.amount_cents<>333 or order_row.kind<>'tournament' or order_row.tournament_id<>tid or order_row.paid_at is not null then raise exception 'Wrong checkout';end if;
 insert into public.paid_tournament_entries(tournament_id,profile_id,registration_source) values(tid,player,'admin');
 original_profile:=(select to_jsonb(p) from public.public_profiles p where id=player);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',subject,'role','authenticated')::text,true);
 response:=public.submit_finishing_tournament_pick(tid,1::smallint,'draw');
 if response->>'enrolled'<>'true' or jsonb_array_length(response->'predictions')<>18 then raise exception 'Enrolled predictions missing';end if;
 perform public.submit_finishing_tournament_pick(tid,1::smallint,'draw');
 if (select count(*) from public.paid_tournament_picks where tournament_id=tid and profile_id=player)<>1 then raise exception 'Retry duplicated pick';end if;
 denied:=false;begin perform public.submit_finishing_tournament_pick(tid,1::smallint,'away');exception when others then if sqlerrm like '%já confirmou%' then denied:=true;else raise;end if;end;
 if not denied then raise exception 'Player changed confirmed pick';end if;
 update public.paid_tournament_predictions set closes_at=clock_timestamp()-interval '3 hours',match_day=((clock_timestamp()-interval '3 hours') at time zone 'America/Sao_Paulo')::date where tournament_id=tid and slot=2;
 denied:=false;begin perform public.submit_finishing_tournament_pick(tid,2::smallint,'away');exception when others then if sqlerrm like '%prazo%' then denied:=true;else raise;end if;end;
 if not denied then raise exception 'Late pick accepted';end if;
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 select value into qa_target from jsonb_array_elements(public.get_automatic_result_targets()) where value->>'tournamentId'=tid::text and value->>'slot'='2';
 if qa_target is null or qa_target->>'metric'<>'classic' then raise exception 'Classic qa_target missing';end if;
 if exists(select 1 from jsonb_array_elements(public.get_automatic_result_targets()) where value->>'tournamentId'='671f995b-18bf-4c49-a706-caff6e580e19') then raise exception 'Cards added to shots worker';end if;
 -- Apuration is isolated to the tournament and refuses early settlement.
 denied:=false;begin perform public.settle_finishing_tournament_prediction(tid,1::smallint,0,0);exception when others then if sqlerrm like '%ainda não começou%' then denied:=true;else raise;end if;end;
 if not denied then raise exception 'Early settlement accepted';end if;
 update public.paid_tournament_predictions set closes_at=clock_timestamp()-interval '3 hours',match_day=((clock_timestamp()-interval '3 hours') at time zone 'America/Sao_Paulo')::date where tournament_id=tid and slot=1;
 perform public.settle_finishing_tournament_prediction(tid,1::smallint,0,0);
 perform public.settle_finishing_tournament_prediction(tid,1::smallint,0,0);
 if (select correct_answers from public.paid_tournament_entries where tournament_id=tid and profile_id=player)<>1 then raise exception 'Draw score not credited once';end if;
 if (select to_jsonb(p) from public.public_profiles p where id=player)<>original_profile then raise exception 'Changed global score or XP';end if;
 -- A full automatic observation uses goals and preserves the ten-minute confirmation window.
 perform set_config('request.jwt.claims',jsonb_build_object('sub',subject,'role','authenticated')::text,true);
 perform public.submit_finishing_tournament_pick(tid,3::smallint,'away');
 update public.paid_tournament_predictions set closes_at=clock_timestamp()-interval '3 hours',match_day=((clock_timestamp()-interval '3 hours') at time zone 'America/Sao_Paulo')::date where tournament_id=tid and slot=3;
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 update public.automatic_results_settings set enabled=true,mode='automatic' where singleton;
 select value into qa_target from jsonb_array_elements(public.get_automatic_result_targets()) where value->>'tournamentId'=tid::text and value->>'slot'='3';
 evidence:=jsonb_build_object('fixtureId',9900601,'homeId',1,'awayId',2,'kickoff',qa_target->>'closesAt','winner','away','homeValue',0,'awayValue',3);
 response:=public.observe_automatic_result(qa_target,evidence);
 if response->>'status'<>'waiting' then raise exception 'Confirmation window bypassed';end if;
 update public.automatic_result_observations set first_seen_at=clock_timestamp()-interval '11 minutes' where target_key=qa_target->>'key';
 response:=public.observe_automatic_result(qa_target,evidence);
 if response->>'status'<>'settled' or (select correct_answers from public.paid_tournament_entries where tournament_id=tid and profile_id=player)<>2 then raise exception 'Classic automatic score failed';end if;
 if (select to_jsonb(p) from public.public_profiles p where id=player)<>original_profile then raise exception 'Automatic score changed global profile';end if;

 perform set_config('request.jwt.claims',jsonb_build_object('sub',other_subject,'role','authenticated')::text,true);
 if public.get_finishing_tournament(tid)->'predictions'<>'[]'::jsonb then raise exception 'Leaked other players picks';end if;
 denied:=false;begin perform public.get_admin_finishing_tournament(tid);exception when others then denied:=true;end;
 if not denied then raise exception 'Non-admin could read administration';end if;
 select auth_user_id into admin_subject from public.private_profiles where profile_id='4325ba8c-8b6b-9635-429c-cef8c63ac2d4';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',admin_subject,'role','authenticated','email',(select owner_email from public.app_config where singleton))::text,true);
 response:=public.get_admin_finishing_tournament(tid);
 if response->>'metric'<>'classic' or jsonb_array_length(response->'availableTournaments')<>2 then raise exception 'Admin modality/list missing';end if;
 response:=public.get_admin_player_tournament_picks(player,tid);
 if response->>'metric'<>'classic' then raise exception 'Admin correction modality missing';end if;
 perform public.settle_finishing_tournament_winner(tid,2::smallint,'away');
 if (select winning_option_id from public.paid_tournament_predictions where tournament_id=tid and slot=2)<>'away' then raise exception 'Manual winner not saved';end if;
 if has_function_privilege('anon','public.available_paid_tournaments_json()','EXECUTE') or has_function_privilege('authenticated','public.available_paid_tournaments_json()','EXECUTE') then raise exception 'Helper exposed';end if;
end $$;
select 'PASS: 18 fixtures, signup/checkout, isolated ranking, retries, deadlines, classic targets, manual apuration, ACLs' as checks;
rollback;
