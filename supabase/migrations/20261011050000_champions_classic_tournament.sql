begin;

-- Classic match result is a separate metric; existing tournaments keep their rules.
alter table public.paid_tournaments drop constraint paid_tournaments_metric_check;
alter table public.paid_tournaments add constraint paid_tournaments_metric_check check(metric in ('shots','cards','classic'));
alter table public.paid_tournaments drop constraint paid_tournaments_prediction_count_check;
alter table public.paid_tournaments add constraint paid_tournaments_prediction_count_check check(prediction_count in (18,20,21));
alter table public.paid_tournaments drop constraint paid_tournaments_check;
alter table public.paid_tournaments add constraint paid_tournaments_check check(ends_at>starts_at and
 ((ends_at-interval '1 microsecond') at time zone 'America/Sao_Paulo')::date =
 (starts_at at time zone 'America/Sao_Paulo')::date + case when metric='classic' then 1 else 2 end);

-- Only public tournament identifiers/titles; no payment or other players' picks.
create function public.available_paid_tournaments_json() returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by created_at desc,id),'[]'::jsonb)
 from public.paid_tournaments where enabled;
$$;
revoke all on function public.available_paid_tournaments_json() from public,anon,authenticated;

CREATE OR REPLACE FUNCTION public.get_finishing_tournament(p_tournament_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare tournament public.paid_tournaments; viewer uuid:=public.own_profile_id();
 enrolled boolean; players jsonb:='[]'::jsonb; own_rank jsonb; participants integer;
begin
 if viewer is null then raise exception 'Entre na sua conta e crie seu perfil.'; end if;
 select * into tournament from public.paid_tournaments
 where enabled and (p_tournament_id is null or id=p_tournament_id) order by created_at desc limit 1;
 if not found then return null; end if;
 enrolled:=exists(select 1 from public.paid_tournament_entries where tournament_id=tournament.id and profile_id=viewer);
 select count(*)::integer into participants from public.paid_tournament_entries where tournament_id=tournament.id;
 if enrolled then
  with ranked as materialized (
   select e.*,row_number() over(order by e.correct_answers desc,e.registered_at,p.player_id)::integer as position
   from public.paid_tournament_entries e join public.public_profiles p on p.id=e.profile_id where e.tournament_id=tournament.id
  ), visible as materialized (
   select r.profile_id,r.position,public.get_public_profile(r.profile_id)
    || jsonb_build_object('position',r.position,'correctAnswers',r.correct_answers) as player
   from ranked r where r.position<=10 or r.profile_id=viewer
  ) select coalesce(jsonb_agg(player order by position) filter(where position<=10),'[]'::jsonb),
   (jsonb_agg(player) filter(where profile_id=viewer))->0 into players,own_rank from visible;
 end if;
 return jsonb_build_object(
  'metric',tournament.metric,'predictionsPublished',exists(select 1 from public.paid_tournament_predictions where tournament_id=tournament.id),'availableTournaments',public.available_paid_tournaments_json(),'matchDays',(select coalesce(jsonb_agg(day order by day),'[]'::jsonb) from (select distinct match_day as day from public.paid_tournament_predictions where tournament_id=tournament.id) days),'id',tournament.id,'name',tournament.name,'startsAt',tournament.starts_at,'endsAt',tournament.ends_at,
  'entryCents',tournament.entry_cents,'prizeCents',case when tournament.prize_mode='entries' then tournament.entry_cents::bigint*participants else tournament.prize_cents end,
  'predictionCount',tournament.prediction_count,'serverTime',floor(extract(epoch from clock_timestamp())*1000)::bigint,
  'enrolled',enrolled,'registrationOpen',not enrolled and now()<tournament.starts_at,
  'participants',participants,'players',players,'ownRank',own_rank,
  'predictions',case when enrolled then public.finishing_tournament_predictions_json(tournament.id,viewer) else '[]'::jsonb end
 );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_admin_finishing_tournament(p_tournament_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare tournament public.paid_tournaments;
begin
 if not public.is_admin() and coalesce(auth.role(), '') <> 'service_role' then raise exception 'Somente o proprietário pode acessar a administração.'; end if;
 select * into tournament from public.paid_tournaments where enabled and (p_tournament_id is null or id=p_tournament_id) order by created_at desc limit 1;
 if not found then return null; end if;
 return jsonb_build_object('metric',tournament.metric,'availableTournaments',public.available_paid_tournaments_json(),'id',tournament.id,'name',tournament.name,'serverTime',floor(extract(epoch from clock_timestamp())*1000)::bigint,
  'predictions',public.finishing_tournament_predictions_json(tournament.id,null));
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_automatic_result_targets()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
 select coalesce(jsonb_agg(target order by target->>'key'),'[]'::jsonb) from (
  select jsonb_build_object('key','daily:'||p.day_id||':'||p.slot,'kind','daily','day',p.day_id,'slot',p.slot,'tournamentId',null,
   'home',trim(m.teams[1]),'away',trim(m.teams[2]),'competition',trim(split_part(split_part(p.description,'·',1),E'\n',1)),
   'closesAt',p.closes_at,'options',(select jsonb_agg(jsonb_build_object('id',o->>'id','label',o->>'label')) from jsonb_array_elements(p.options) o)) target
  from public.predictions p cross join lateral (select regexp_match(p.title,'\(([^()]+) x ([^()]+)\)$') teams) m
  where p.status='open' and p.title like 'Partida Clássica%Quem vence?%' and m.teams is not null
   and p.closes_at<=clock_timestamp()-interval '90 minutes' and p.closes_at>=clock_timestamp()-interval '7 days'
  union all
  select jsonb_build_object('key','tournament:'||p.tournament_id||':'||p.slot,'kind','tournament','day',p.match_day,'slot',p.slot,
   'metric',t.metric,'tournamentId',p.tournament_id,'home',p.home_team,'away',p.away_team,'competition',p.competition,'closesAt',p.closes_at,'options','[]'::jsonb)
  from public.paid_tournament_predictions p join public.paid_tournaments t on t.id=p.tournament_id
  where p.status='open' and t.enabled and t.metric in ('shots','classic') and p.closes_at<=clock_timestamp()-interval '90 minutes' and p.closes_at>=clock_timestamp()-interval '7 days'
 ) pending;
$function$
;

CREATE OR REPLACE FUNCTION public.settle_finishing_tournament_prediction(p_tournament_id uuid, p_slot smallint, p_home_shots integer, p_away_shots integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare game public.paid_tournament_predictions; winner text;
begin
 if not public.is_admin() and coalesce(auth.role(), '') <> 'service_role' then raise exception 'Somente o proprietário pode concluir os palpites do torneio.'; end if;
 if p_home_shots is null or p_away_shots is null or p_home_shots not between 0 and 300 or p_away_shots not between 0 and 300 then raise exception 'Informe totais de finalizações válidos.'; end if;
 -- Serialize settlements of different games so concurrent totals cannot lose an acerto.
 perform 1 from public.paid_tournaments where id=p_tournament_id for update;
 select * into game from public.paid_tournament_predictions where tournament_id=p_tournament_id and slot=p_slot for update;
 if not found then raise exception 'Palpite do torneio não encontrado.'; end if;
 if game.status='settled' then
  if game.home_shots is distinct from p_home_shots or game.away_shots is distinct from p_away_shots then raise exception 'Este resultado já foi confirmado.'; end if;
  return public.get_admin_finishing_tournament(p_tournament_id);
 end if;
 if clock_timestamp()<game.closes_at then raise exception 'A partida ainda não começou.'; end if;
 winner:=case when p_home_shots>p_away_shots then 'home' when p_home_shots<p_away_shots then 'away' else 'draw' end;
 update public.paid_tournament_predictions set status='settled',home_shots=p_home_shots,away_shots=p_away_shots,winning_option_id=winner,settled_at=clock_timestamp()
 where tournament_id=p_tournament_id and slot=p_slot;
 update public.paid_tournament_entries e set correct_answers=(
  select count(*)::integer from public.paid_tournament_picks p join public.paid_tournament_predictions g
   on g.tournament_id=p.tournament_id and g.slot=p.slot
  where p.tournament_id=e.tournament_id and p.profile_id=e.profile_id and g.status='settled' and p.option_id=g.winning_option_id
 ) where e.tournament_id=p_tournament_id;
 return public.get_admin_finishing_tournament(p_tournament_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.observe_automatic_result(p_target jsonb, p_evidence jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare current_target jsonb; previous public.automatic_result_observations; settings public.automatic_results_settings;
 winner text; h integer; a integer; result jsonb; signature text;
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'Acesso restrito ao servidor.'; end if;
 -- Lock settings so disabling automation cannot race an in-flight settlement.
 select * into settings from public.automatic_results_settings where singleton for update;
 if not settings.enabled then return jsonb_build_object('status','disabled'); end if;
 select value into current_target from jsonb_array_elements(public.get_automatic_result_targets()) where value->>'key'=p_target->>'key';
 if current_target is null then return jsonb_build_object('status','skipped'); end if;
 if current_target<>p_target then raise exception 'O palpite foi alterado. Refaça a consulta.'; end if;
 winner:=p_evidence->>'winner'; h:=(p_evidence->>'homeValue')::integer; a:=(p_evidence->>'awayValue')::integer;
 if h is null or a is null or h not between 0 and 300 or a not between 0 and 300
  or coalesce((p_evidence->>'fixtureId')::bigint,0)<=0 or coalesce((p_evidence->>'homeId')::bigint,0)<=0 or coalesce((p_evidence->>'awayId')::bigint,0)<=0
  or p_evidence->>'kickoff' is null
  or p_evidence->>'homeId'=p_evidence->>'awayId'
  or abs(extract(epoch from ((p_evidence->>'kickoff')::timestamptz-(p_target->>'closesAt')::timestamptz)))>300
 then raise exception 'Evidência inválida.'; end if;
 if p_target->>'kind'='tournament' then
  if coalesce(p_target->>'metric','shots') not in ('shots','classic') then raise exception 'Modalidade automática inválida.'; end if;
  if winner is distinct from (case when h>a then 'home' when h<a then 'away' else 'draw' end) then raise exception 'Resultado incompatível com os totais.'; end if;
 else
  if winner is null or not exists(select 1 from jsonb_array_elements(p_target->'options') o where o->>'id'=winner) then raise exception 'Opção inválida.'; end if;
 end if;
 -- Construct the signature on the database too; never trust a caller's signature.
 signature:=jsonb_build_object('target',p_target,'fixtureId',p_evidence->'fixtureId','homeId',p_evidence->'homeId','awayId',p_evidence->'awayId','kickoff',p_evidence->'kickoff','winner',winner,'home',h,'away',a)::text;
 select * into previous from public.automatic_result_observations where target_key=p_target->>'key' for update;
 if not found or previous.signature is distinct from signature then
  insert into public.automatic_result_observations(target_key,target,evidence,signature,first_seen_at,last_seen_at,status)
  values(p_target->>'key',p_target,p_evidence,signature,clock_timestamp(),clock_timestamp(),'waiting')
  on conflict(target_key) do update set target=excluded.target,evidence=excluded.evidence,signature=excluded.signature,first_seen_at=excluded.first_seen_at,last_seen_at=excluded.last_seen_at,status='waiting',issue=null;
  return jsonb_build_object('status','waiting');
 end if;
 update public.automatic_result_observations set last_seen_at=clock_timestamp(),issue=null where target_key=p_target->>'key';
 if clock_timestamp()-previous.first_seen_at<interval '10 minutes' then return jsonb_build_object('status','waiting'); end if;
 if settings.mode='shadow' then
  update public.automatic_result_observations set status='suggested' where target_key=p_target->>'key';
  return jsonb_build_object('status','suggested');
 end if;
 if p_target->>'kind'='tournament' then
  result:=public.settle_finishing_tournament_prediction((p_target->>'tournamentId')::uuid,(p_target->>'slot')::smallint,h,a);
 else
  result:=public.settle_prediction_for_slot((p_target->>'day')::date,(p_target->>'slot')::smallint,winner);
 end if;
 update public.automatic_result_observations set status='settled',settled_at=clock_timestamp() where target_key=p_target->>'key';
 return jsonb_build_object('status','settled');
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_admin_player_tournament_picks(p_profile_id uuid, p_tournament_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$

declare tournament public.paid_tournaments; hits integer;

begin

 if not public.is_admin() then raise exception 'Somente o proprietário pode consultar palpites de jogadores.'; end if;

 if not exists(select 1 from public.public_profiles where id=p_profile_id) then raise exception 'Jogador não encontrado.'; end if;

 select * into tournament from public.paid_tournaments

 where enabled and (p_tournament_id is null or id=p_tournament_id) order by created_at desc,id limit 1;

 if not found then return null; end if;

 select correct_answers into hits from public.paid_tournament_entries

 where tournament_id=tournament.id and profile_id=p_profile_id;

 return jsonb_build_object('availableTournaments',public.available_paid_tournaments_json(),'metric',tournament.metric,'id',tournament.id,'name',tournament.name,'enrolled',hits is not null,

  'correctAnswers',coalesce(hits,0),'predictions',case when hits is not null

   then public.finishing_tournament_predictions_json(tournament.id,p_profile_id) else '[]'::jsonb end);

end;

$function$
;

-- UEFA official matchday 2 fixtures, verified 11/10/2026.
-- https://www.uefa.com/uefachampionsleague/news/02a8-2174c9e9019d-f909a77bd77a-1000--2026-27-champions-league-all-the-league-phase-fixtures/
-- European summer time UTC+2 -> Brasília UTC-3: 18:45 = 13:45; 21:00 = 16:00.
insert into public.paid_tournaments(id,name,starts_at,ends_at,entry_cents,prize_cents,prediction_count,prize_mode,metric)
values ('2e0617ac-f47a-4abd-aae8-68b4c59aa12d','Torneio Champions League · Rodada 2','2026-10-13T13:30:00-03:00','2026-10-15T00:00:00-03:00',333,0,18,'entries','classic');
insert into public.paid_tournament_predictions(tournament_id,slot,match_day,home_team,away_team,title,competition,closes_at)
select '2e0617ac-f47a-4abd-aae8-68b4c59aa12d',slot::smallint,day::date,home_team,away_team,'Partida Clássica — Quem vence?','UEFA Champions League',deadline::timestamptz from (values
 (1,'2026-10-13','Lens','Sporting CP','2026-10-13T13:45:00-03:00'),
 (2,'2026-10-13','Sabah','Slavia Praha','2026-10-13T13:45:00-03:00'),
 (3,'2026-10-13','Arsenal','Lille','2026-10-13T16:00:00-03:00'),
 (4,'2026-10-13','Atlético de Madrid','Manchester United','2026-10-13T16:00:00-03:00'),
 (5,'2026-10-13','Inter','Club Brugge','2026-10-13T16:00:00-03:00'),
 (6,'2026-10-13','Galatasaray','Barcelona','2026-10-13T16:00:00-03:00'),
 (7,'2026-10-13','RB Leipzig','PSV Eindhoven','2026-10-13T16:00:00-03:00'),
 (8,'2026-10-13','Viking','Bayern de Munique','2026-10-13T16:00:00-03:00'),
 (9,'2026-10-13','Villarreal','Napoli','2026-10-13T16:00:00-03:00'),
 (10,'2026-10-14','Feyenoord','Como','2026-10-14T13:45:00-03:00'),
 (11,'2026-10-14','LASK','Liverpool','2026-10-14T13:45:00-03:00'),
 (12,'2026-10-14','Roma','Real Madrid','2026-10-14T16:00:00-03:00'),
 (13,'2026-10-14','Aston Villa','Fenerbahçe','2026-10-14T16:00:00-03:00'),
 (14,'2026-10-14','Shakhtar Donetsk','AEK Athens','2026-10-14T16:00:00-03:00'),
 (15,'2026-10-14','Bodø/Glimt','Borussia Dortmund','2026-10-14T16:00:00-03:00'),
 (16,'2026-10-14','Manchester City','Paris Saint-Germain','2026-10-14T16:00:00-03:00'),
 (17,'2026-10-14','Real Betis','Porto','2026-10-14T16:00:00-03:00'),
 (18,'2026-10-14','Slovan Bratislava','Stuttgart','2026-10-14T16:00:00-03:00')
) fixtures(slot,day,home_team,away_team,deadline);

notify pgrst,'reload schema';
commit;
