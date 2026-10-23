-- Run with the migration in a transaction ending in ROLLBACK.
create temporary table profiles_before as select id,to_jsonb(p) data from public.public_profiles p;
insert into public.public_profiles(id,player_id,username,avatar_color)
values ('aaaaaaaa-1111-4111-8111-111111111111',9900201,'editqa1','#3b82f6'),
 ('bbbbbbbb-2222-4222-8222-222222222222',9900202,'editqa2','#22c55e'),
 ('cccccccc-3333-4333-8333-333333333333',9900203,'editqa3','#ec4899');
create temporary table qa_profiles_before as select id,to_jsonb(p) data from public.public_profiles p where player_id between 9900201 and 9900203;
insert into public.paid_tournaments(id,name,metric,starts_at,ends_at,entry_cents,prize_cents,prize_mode,enabled)
values('dddddddd-4444-4444-8444-444444444444','Torneio QA','cards','2099-10-08T00:00:00-03:00','2099-10-11T00:00:00-03:00',333,0,'entries',true);
insert into public.paid_tournament_entries(tournament_id,profile_id,registration_source,correct_answers)
values('dddddddd-4444-4444-8444-444444444444','aaaaaaaa-1111-4111-8111-111111111111','admin',0),
 ('dddddddd-4444-4444-8444-444444444444','bbbbbbbb-2222-4222-8222-222222222222','admin',1);
insert into public.paid_tournament_predictions(tournament_id,slot,match_day,home_team,away_team,closes_at,status,winning_option_id,settled_at)
select 'dddddddd-4444-4444-8444-444444444444',slot::smallint,'2099-10-08','Casa QA','Fora QA','2099-10-08T12:00:00-03:00',
 case when slot=1 then 'settled' else 'open' end,case when slot=1 then 'home' end,case when slot=1 then now() end
from generate_series(1,3) slot;
insert into public.paid_tournament_picks(tournament_id,slot,profile_id,option_id)
values('dddddddd-4444-4444-8444-444444444444',1,'aaaaaaaa-1111-4111-8111-111111111111','away'),
 ('dddddddd-4444-4444-8444-444444444444',1,'bbbbbbbb-2222-4222-8222-222222222222','home');
create temporary table official_results_before as select slot,to_jsonb(g) data from public.paid_tournament_predictions g where tournament_id='dddddddd-4444-4444-8444-444444444444';
select set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'email',(select owner_email from public.app_config where singleton))::text,true);
do $$
declare player uuid:='aaaaaaaa-1111-4111-8111-111111111111'; tour uuid:='dddddddd-4444-4444-8444-444444444444'; state jsonb;
begin
 state:=public.get_admin_player_tournament_picks(player,tour);
 if not (state->>'enrolled')::boolean or state->>'correctAnswers'<>'0' or state->'predictions'->0->>'myOptionId'<>'away' then raise exception 'Read state incorrect'; end if;
 if (public.get_admin_player_tournament_picks('cccccccc-3333-4333-8333-333333333333',tour)->>'enrolled')::boolean then raise exception 'Unenrolled shown enrolled'; end if;
 state:=public.admin_save_tournament_pick(player,tour,1::smallint,'home','away');
 if state->>'correctAnswers'<>'1' or state->'predictions'->0->>'myResult'<>'correct' then raise exception 'Wrong to correct score missing'; end if;
 perform public.admin_save_tournament_pick(player,tour,1::smallint,'home','away');
 if (select count(*) from public.admin_tournament_pick_corrections where tournament_id=tour)<>1 then raise exception 'Replay duplicated audit'; end if;
 begin perform public.admin_save_tournament_pick(player,tour,1::smallint,'draw','away'); raise exception 'Stale allowed';
 exception when others then if sqlerrm<>'O palpite mudou. Recarregue a lista antes de corrigir.' then raise; end if; end;
 state:=public.admin_save_tournament_pick(player,tour,1::smallint,'draw','home');
 if state->>'correctAnswers'<>'0' then raise exception 'Correct to wrong score missing'; end if;
 -- Add and edit a pending pick, then add to a settled match after the deadline.
 perform public.admin_save_tournament_pick(player,tour,2::smallint,'away',null);
 perform public.admin_save_tournament_pick(player,tour,2::smallint,'draw','away');
 update public.paid_tournament_predictions set status='settled',winning_option_id='draw',settled_at=now(),closes_at='2026-10-09T12:00:00-03:00',match_day='2026-10-09' where tournament_id=tour and slot=3;
 state:=public.admin_save_tournament_pick(player,tour,3::smallint,'draw',null);
 if state->>'correctAnswers'<>'1' then raise exception 'Settled missing pick not counted'; end if;
 if (select correct_answers from public.paid_tournament_entries where tournament_id=tour and profile_id='bbbbbbbb-2222-4222-8222-222222222222')<>1 then raise exception 'Other entry changed'; end if;
 if (select option_id from public.paid_tournament_picks where tournament_id=tour and profile_id='bbbbbbbb-2222-4222-8222-222222222222' and slot=1)<>'home' then raise exception 'Other pick changed'; end if;
 if exists(select 1 from qa_profiles_before s join public.public_profiles p using(id) where s.data<>to_jsonb(p)) or exists(select 1 from profiles_before s join public.public_profiles p using(id) where s.data<>to_jsonb(p)) then raise exception 'Global stats changed'; end if;
 if exists(select 1 from official_results_before s join public.paid_tournament_predictions g using(slot) where g.tournament_id=tour and slot<3 and s.data<>to_jsonb(g)) then raise exception 'Official result changed'; end if;
 if (select sum(correct_answers_delta) from public.admin_tournament_pick_corrections where tournament_id=tour)<>1 then raise exception 'Audit deltas wrong'; end if;
 begin perform public.admin_save_tournament_pick(player,tour,1::smallint,'invalid','draw'); raise exception 'Invalid allowed';
 exception when others then if sqlerrm<>'Escolha Casa, Empate ou Fora.' then raise; end if; end;
 begin perform public.admin_save_tournament_pick('cccccccc-3333-4333-8333-333333333333',tour,1::smallint,'home',null); raise exception 'Unenrolled allowed';
 exception when others then if sqlerrm<>'Este jogador não está inscrito no torneio.' then raise; end if; end;
 begin perform public.admin_save_tournament_pick(player,tour,21::smallint,'home',null); raise exception 'Missing match allowed';
 exception when others then if sqlerrm<>'Palpite do torneio não encontrado.' then raise; end if; end;
 if has_function_privilege('anon','public.admin_save_tournament_pick(uuid,uuid,smallint,text,text)','EXECUTE') or has_function_privilege('anon','public.get_admin_player_tournament_picks(uuid,uuid)','EXECUTE') or has_table_privilege('authenticated','public.admin_tournament_pick_corrections','SELECT') then raise exception 'Private access exposed'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'email','ordinary@example.test')::text,true);
 begin perform public.admin_save_tournament_pick(player,tour,1::smallint,'home','draw'); raise exception 'Non admin allowed';
 exception when others then if sqlerrm<>'Somente o proprietário pode editar palpites do torneio.' then raise; end if; end;
 begin perform public.get_admin_player_tournament_picks(player,tour); raise exception 'Non admin read allowed';
 exception when others then if sqlerrm<>'Somente o proprietário pode consultar palpites de jogadores.' then raise; end if; end;
end;
$$;
select set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'email',(select owner_email from public.app_config where singleton))::text,true);
set local role authenticated;
do $$
declare state jsonb;
begin
 state:=public.admin_save_tournament_pick('aaaaaaaa-1111-4111-8111-111111111111','dddddddd-4444-4444-8444-444444444444',1::smallint,'home','draw');
 if state->>'correctAnswers'<>'2' then raise exception 'Authenticated admin RPC failed'; end if;
end;
$$;
reset role;
select 'PASS: admin-only read/write, correction and addition, stale protection, replay, ranking, isolated stats, audit and access control' as result;
