begin;
create table public.automatic_results_settings (
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 mode text not null default 'shadow' check(mode in ('shadow','automatic')),
 lease_token uuid, lease_until timestamptz, last_run_at timestamptz,
 last_summary jsonb not null default '{}'
);
insert into public.automatic_results_settings(singleton) values(true);
create table public.automatic_result_observations (
 target_key text primary key, target jsonb not null,
 evidence jsonb, signature text, first_seen_at timestamptz, last_seen_at timestamptz,
 status text not null default 'waiting' check(status in ('waiting','suggested','settled','review')),
 issue text, settled_at timestamptz
);
alter table public.automatic_results_settings enable row level security;
alter table public.automatic_result_observations enable row level security;
revoke all on public.automatic_results_settings,public.automatic_result_observations from public,anon,authenticated;
grant select,update on public.automatic_results_settings to service_role;
grant select on public.automatic_result_observations to service_role;

-- Reuse the deployed settlement routines rather than copy their XP/rank logic.
-- The service role already has full database access; no player gains permission.
do $$
declare routine regprocedure; source text; updated text;
begin
 foreach routine in array array[
  'public.settle_prediction_for_slot(date,smallint,text)'::regprocedure,
  'public.settle_finishing_tournament_prediction(uuid,smallint,integer,integer)'::regprocedure,
  'public.get_admin_finishing_tournament(uuid)'::regprocedure
 ] loop
  source:=pg_get_functiondef(routine);
  updated:=replace(source,'if not public.is_admin() then','if not public.is_admin() and coalesce(auth.role(), '''') <> ''service_role'' then');
  if source=updated then raise exception 'Authorization guard not found: %',routine; end if;
  execute updated;
 end loop;
end;
$$;
grant execute on function public.settle_prediction_for_slot(date,smallint,text),public.settle_finishing_tournament_prediction(uuid,smallint,integer,integer),public.get_admin_finishing_tournament(uuid) to service_role;

create function public.get_automatic_result_targets()
returns jsonb language sql stable security definer set search_path=public,auth,pg_temp as $$
 select coalesce(jsonb_agg(target order by target->>'key'),'[]'::jsonb) from (
  select jsonb_build_object('key','daily:'||p.day_id||':'||p.slot,'kind','daily','day',p.day_id,'slot',p.slot,'tournamentId',null,
   'home',trim(m.teams[1]),'away',trim(m.teams[2]),'competition',trim(split_part(split_part(p.description,'·',1),E'\n',1)),
   'closesAt',p.closes_at,'options',(select jsonb_agg(jsonb_build_object('id',o->>'id','label',o->>'label')) from jsonb_array_elements(p.options) o)) target
  from public.predictions p cross join lateral (select regexp_match(p.title,'\(([^()]+) x ([^()]+)\)$') teams) m
  where p.status='open' and p.title like 'Partida Clássica%Quem vence?%' and m.teams is not null
   and p.closes_at<=clock_timestamp()-interval '90 minutes' and p.closes_at>=clock_timestamp()-interval '7 days'
  union all
  select jsonb_build_object('key','tournament:'||p.tournament_id||':'||p.slot,'kind','tournament','day',p.match_day,'slot',p.slot,
   'tournamentId',p.tournament_id,'home',p.home_team,'away',p.away_team,'competition',p.competition,'closesAt',p.closes_at,'options','[]'::jsonb)
  from public.paid_tournament_predictions p join public.paid_tournaments t on t.id=p.tournament_id
  where p.status='open' and t.enabled and p.closes_at<=clock_timestamp()-interval '90 minutes' and p.closes_at>=clock_timestamp()-interval '7 days'
 ) pending;
$$;
revoke all on function public.get_automatic_result_targets() from public,anon,authenticated;
grant execute on function public.get_automatic_result_targets() to service_role;

create function public.claim_automatic_results_run(p_token uuid)
returns boolean language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'Acesso restrito ao servidor.'; end if;
 update public.automatic_results_settings set lease_token=p_token,lease_until=clock_timestamp()+interval '4 minutes'
 where singleton and enabled and (lease_until is null or lease_until<clock_timestamp());
 return found;
end;
$$;
create function public.finish_automatic_results_run(p_token uuid,p_summary jsonb)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'Acesso restrito ao servidor.'; end if;
 update public.automatic_results_settings set lease_token=null,lease_until=null,last_run_at=clock_timestamp(),last_summary=p_summary
 where singleton and lease_token=p_token;
end;
$$;
create function public.record_automatic_result_issue(p_key text,p_issue text)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target jsonb;
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'Acesso restrito ao servidor.'; end if;
 select value into target from jsonb_array_elements(public.get_automatic_result_targets()) where value->>'key'=p_key;
 if target is null then return; end if;
 insert into public.automatic_result_observations(target_key,target,status,issue,last_seen_at) values(p_key,target,'review',left(p_issue,200),clock_timestamp())
 on conflict(target_key) do update set status='review',issue=excluded.issue,signature=null,first_seen_at=null,last_seen_at=excluded.last_seen_at
 where automatic_result_observations.status<>'settled';
end;
$$;

create function public.observe_automatic_result(p_target jsonb,p_evidence jsonb)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
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
$$;
revoke all on function public.claim_automatic_results_run(uuid),public.finish_automatic_results_run(uuid,jsonb),public.record_automatic_result_issue(text,text),public.observe_automatic_result(jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.claim_automatic_results_run(uuid),public.finish_automatic_results_run(uuid,jsonb),public.record_automatic_result_issue(text,text),public.observe_automatic_result(jsonb,jsonb) to service_role;

create function public.get_automatic_results_status()
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
 if not public.is_admin() then raise exception 'Somente o proprietário pode acessar a administração.'; end if;
 return (select jsonb_build_object('enabled',s.enabled,'mode',s.mode,'lastRunAt',s.last_run_at,'summary',s.last_summary,
  'observations',coalesce((select jsonb_agg(to_jsonb(o) order by o.last_seen_at desc) from (select target,evidence,status,issue,last_seen_at from public.automatic_result_observations order by last_seen_at desc limit 30) o),'[]'::jsonb))
  from public.automatic_results_settings s where singleton);
end;
$$;
revoke all on function public.get_automatic_results_status() from public,anon,authenticated;
grant execute on function public.get_automatic_results_status() to authenticated;

-- Runs independently of browsers. Paused until API credentials and coverage are
-- checked; shadow mode never awards points or changes a ticket.
select cron.schedule('automatic-football-results','*/5 * * * *',$job$
 select net.http_post(
  url := 'https://kvvctmkxdvgdashxwpjb.supabase.co/functions/v1/auto-results',
  headers := jsonb_build_object('Content-Type','application/json','x-auto-results-secret',(select decrypted_secret from vault.decrypted_secrets where name='auto_results_schedule_secret')),
  body := '{}'::jsonb, timeout_milliseconds := 120000
 ) where (select enabled from public.automatic_results_settings where singleton)
  and exists(select 1 from vault.decrypted_secrets where name='auto_results_schedule_secret');
 $job$);
notify pgrst,'reload schema';
commit;
