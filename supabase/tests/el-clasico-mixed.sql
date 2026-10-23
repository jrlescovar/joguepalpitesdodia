begin;
create temporary table el_clasico_legacy_before as
select jsonb_build_object('tournaments',(select jsonb_agg(to_jsonb(t) order by id) from public.paid_tournaments t where id<>'2270fca1-406c-4da0-8582-20c20520a44c'),
 'predictions',(select jsonb_agg(to_jsonb(g)-'options'-'rules' order by tournament_id,slot) from public.paid_tournament_predictions g where tournament_id<>'2270fca1-406c-4da0-8582-20c20520a44c'),
 'entries',(select jsonb_agg(to_jsonb(e) order by tournament_id,profile_id) from public.paid_tournament_entries e where tournament_id<>'2270fca1-406c-4da0-8582-20c20520a44c'),
 'picks',(select jsonb_agg(to_jsonb(p) order by tournament_id,slot,profile_id) from public.paid_tournament_picks p where tournament_id<>'2270fca1-406c-4da0-8582-20c20520a44c')) as snapshot;
do $$
declare tid uuid:='2270fca1-406c-4da0-8582-20c20520a44c'; player uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid();
 subject uuid:=gen_random_uuid(); other_subject uuid:=gen_random_uuid(); admin_subject uuid; response jsonb; denied boolean;
 original_profile jsonb; purchase public.infinitepay_orders; reused public.infinitepay_orders; request_id uuid:=gen_random_uuid();
 game record; legacy_after jsonb;
begin
 if not exists(select 1 from public.paid_tournaments where id=tid and name='EL CLÁSSICO' and metric='mixed' and enabled and entry_cents=444
  and prediction_count=20 and prize_mode='entries' and starts_at='2026-10-25T16:50:00-03:00' and ends_at='2026-10-26T00:00:00-03:00') then raise exception 'Tournament configuration mismatch'; end if;
 if (select count(*) from public.paid_tournament_predictions where tournament_id=tid)<>20
  or (select count(distinct title) from public.paid_tournament_predictions where tournament_id=tid)<>20
  or exists(select 1 from public.paid_tournament_predictions where tournament_id=tid and (home_team<>'Barcelona' or away_team<>'Real Madrid' or closes_at<>'2026-10-25T16:50:00-03:00' or match_day<>'2026-10-25')) then raise exception 'Missing or incorrect markets'; end if;
 if (select count(*) from public.paid_tournament_predictions where tournament_id=tid and jsonb_array_length(options)=2)<>4 then raise exception 'Incorrect binary markets'; end if;
 if (select title from public.paid_tournament_predictions where tournament_id=tid and slot=19)<>'Vai ter cartão vermelho?'
  or (select title from public.paid_tournament_predictions where tournament_id=tid and slot=20)<>'Vai ter mais de 5,5 cartões?' then raise exception 'Approved replacements missing'; end if;
 insert into public.public_profiles(id,player_id,username,avatar_color) values(player,9900801,'elclasicoqa1','#3b82f6'),(outsider,9900802,'elclasicoqa2','#3b82f6');
 insert into public.private_profiles(profile_id,auth_user_id,email) values(player,subject,'elclasicoqa1@example.invalid'),(outsider,other_subject,'elclasicoqa2@example.invalid');
 original_profile:=(select to_jsonb(p) from public.public_profiles p where id=player);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other_subject,'role','authenticated')::text,true);
 response:=public.get_finishing_tournament(tid);
 if response->>'registrationOpen'<>'true' or response->>'enrolled'<>'false' or response->>'entryCents'<>'444' or response->'predictions'<>'[]'::jsonb
  or jsonb_array_length(response->'matchDays')<>1 or jsonb_array_length(response->'availableTournaments')<>3 then raise exception 'Signup/list/privacy mismatch'; end if;
 denied:=false;begin perform public.submit_finishing_tournament_pick(tid,1::smallint,'home');exception when others then if sqlerrm like '%Inscreva-se%' then denied:=true;else raise;end if;end;
 if not denied then raise exception 'Unenrolled pick accepted'; end if;
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 purchase:=public.reserve_tournament_order(outsider,request_id,'el-clasico-qa',tid);
 reused:=public.reserve_tournament_order(outsider,request_id,'el-clasico-qa',tid);
 if purchase.amount_cents<>444 or purchase.kind<>'tournament' or purchase.tournament_id<>tid or purchase.id<>reused.id or purchase.paid_at is not null then raise exception 'Checkout/price/retry mismatch'; end if;
 insert into public.paid_tournament_entries(tournament_id,profile_id,registration_source) values(tid,player,'admin');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',subject,'role','authenticated')::text,true);
 denied:=false;begin perform public.submit_finishing_tournament_pick(tid,8::smallint,'draw');exception when others then if sqlerrm like '%Opção inválida%' then denied:=true;else raise;end if;end;
 if not denied then raise exception 'Forged binary third choice accepted'; end if;
 for game in select * from public.paid_tournament_predictions where tournament_id=tid order by slot loop
  response:=public.submit_finishing_tournament_pick(tid,game.slot,'home');
 end loop;
 perform public.submit_finishing_tournament_pick(tid,9::smallint,'home');
 if (select count(*) from public.paid_tournament_picks where tournament_id=tid and profile_id=player)<>20 or jsonb_array_length(response->'predictions')<>20 then raise exception 'Pick identity/retry mismatch'; end if;
 if response->'predictions'->7->'options'->0->>'label'<>'Sim' or response->'predictions'->8->'options'->1->>'label'<>'3–4'
  or response->'predictions'->12->'options'->1->>'label'<>'3–5' or response->'predictions'->15->'options'->1->>'label'<>'Nenhum' then raise exception 'Serialized market labels wrong'; end if;
 denied:=false;begin perform public.get_admin_finishing_tournament(tid);exception when others then denied:=true;end;
 if not denied then raise exception 'Non-admin accessed results'; end if;
 select auth_user_id into admin_subject from public.private_profiles where profile_id='4325ba8c-8b6b-9635-429c-cef8c63ac2d4';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',admin_subject,'role','authenticated','email',(select owner_email from public.app_config where singleton))::text,true);
 denied:=false;begin perform public.settle_finishing_tournament_winner(tid,1::smallint,'home');exception when others then if sqlerrm like '%ainda não começou%' then denied:=true;else raise;end if;end;
 if not denied then raise exception 'Early settlement accepted'; end if;
 -- Validate the actual correction RPC, including audit rollback on invalid choices.
 denied:=false;begin perform public.admin_save_tournament_pick(player,tid,8::smallint,'draw','home');exception when others then if sqlerrm like '%Opção inválida%' then denied:=true;else raise;end if;end;
 if not denied then raise exception 'Admin binary third choice accepted'; end if;
 denied:=false;begin update public.paid_tournament_predictions set rules='Altered after picks' where tournament_id=tid and slot=1;exception when others then if sqlerrm like '%já respondido%' then denied:=true;else raise;end if;end;
 if not denied then raise exception 'Market rule changed after picks'; end if;
 update public.paid_tournament_predictions set closes_at=clock_timestamp()-interval '4 hours',match_day=((clock_timestamp()-interval '4 hours') at time zone 'America/Sao_Paulo')::date where tournament_id=tid;
 insert into public.paid_tournament_entries(tournament_id,profile_id,registration_source) values(tid,outsider,'admin');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other_subject,'role','authenticated')::text,true);
 denied:=false;begin perform public.submit_finishing_tournament_pick(tid,19::smallint,'home');exception when others then if sqlerrm like '%prazo%' then denied:=true;else raise;end if;end;
 if not denied then raise exception 'Late mixed-market pick accepted'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',admin_subject,'role','authenticated','email',(select owner_email from public.app_config where singleton))::text,true);
 if exists(select 1 from jsonb_array_elements(public.get_automatic_result_targets()) o where o->>'tournamentId'=tid::text) then raise exception 'Mixed market exposed to score-only automation'; end if;
 denied:=false;begin perform public.settle_finishing_tournament_winner(tid,20::smallint,'draw');exception when others then if sqlerrm like '%Opção inválida%' then denied:=true;else raise;end if;end;
 if not denied then raise exception 'Binary invalid winner accepted'; end if;
 denied:=false;begin perform public.settle_finishing_tournament_prediction(tid,9::smallint,3,1);exception when others then if sqlerrm like '%opção vencedora%' then denied:=true;else raise;end if;end;
 if not denied then raise exception 'Range treated as comparative totals'; end if;
 for game in select * from public.paid_tournament_predictions where tournament_id=tid order by slot loop
  perform public.settle_finishing_tournament_winner(tid,game.slot,'home');
 end loop;
 perform public.settle_finishing_tournament_winner(tid,9::smallint,'home');
 if (select correct_answers from public.paid_tournament_entries where tournament_id=tid and profile_id=player)<>20 then raise exception 'Mixed result score/retry mismatch'; end if;
 perform public.admin_save_tournament_pick(player,tid,8::smallint,'away','home');
 if (select correct_answers from public.paid_tournament_entries where tournament_id=tid and profile_id=player)<>19 then raise exception 'Correction ranking mismatch'; end if;
 if (select to_jsonb(p) from public.public_profiles p where id=player)<>original_profile then raise exception 'Tournament changed global profile'; end if;
 if has_function_privilege('anon','public.finishing_tournament_predictions_json(uuid,uuid)','EXECUTE') or has_function_privilege('authenticated','public.finishing_tournament_predictions_json(uuid,uuid)','EXECUTE')
  or has_function_privilege('authenticated','public.validate_tournament_market()','EXECUTE') or has_function_privilege('anon','public.validate_tournament_market_pick()','EXECUTE') then raise exception 'Private helper exposed'; end if;
 select jsonb_build_object('tournaments',(select jsonb_agg(to_jsonb(t) order by id) from public.paid_tournaments t where id<>tid),
  'predictions',(select jsonb_agg(to_jsonb(g)-'options'-'rules' order by tournament_id,slot) from public.paid_tournament_predictions g where tournament_id<>tid),
  'entries',(select jsonb_agg(to_jsonb(e) order by tournament_id,profile_id) from public.paid_tournament_entries e where tournament_id<>tid),
  'picks',(select jsonb_agg(to_jsonb(p) order by tournament_id,slot,profile_id) from public.paid_tournament_picks p where tournament_id<>tid)) into legacy_after;
 if legacy_after is distinct from (select snapshot from el_clasico_legacy_before) then raise exception 'Legacy tournament data changed'; end if;
end $$;
select 'PASS: 20 mixed markets, private choices, exact 444 checkout, signup, retries, binary validation, admin results/corrections, isolated ranking, ACLs and old tournaments preserved' as checks;
rollback;
