begin;

-- Requested ordering applies to the initial selection and the arrow controls.
alter table public.paid_tournaments add column display_order smallint not null default 100 check(display_order>=0);
update public.paid_tournaments set display_order=0 where id='2e0617ac-f47a-4abd-aae8-68b4c59aa12d';
update public.paid_tournaments set display_order=1 where id='2270fca1-406c-4da0-8582-20c20520a44c';
create or replace function public.available_paid_tournaments_json() returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by display_order,created_at desc,id),'[]'::jsonb)
 from public.paid_tournaments where enabled;
$$;
revoke all on function public.available_paid_tournaments_json() from public,anon,authenticated;

do $$
declare signature text; definition text; anchor text;
begin
 foreach signature in array array['public.get_finishing_tournament(uuid)','public.get_admin_finishing_tournament(uuid)','public.get_admin_player_tournament_picks(uuid,uuid)'] loop
  definition:=pg_get_functiondef(signature::regprocedure);
  anchor:=case when signature like '%get_admin_player%' then 'order by created_at desc,id limit 1;' else 'order by created_at desc limit 1;' end;
  if position(anchor in definition)=0 then raise exception 'Ordenação inesperada em %.',signature; end if;
  execute replace(definition,anchor,'order by display_order,created_at desc,id limit 1;');
 end loop;
end $$;

-- The owner explicitly requested deletion of this finished tournament and its data.
-- A complete local backup was saved before this migration; no other event is removed.
do $$
declare target public.paid_tournaments;
begin
 select * into target from public.paid_tournaments where id='671f995b-18bf-4c49-a706-caff6e580e19' for update;
 if found then
  if target.name<>'Torneio Duelo de Cartões' or target.metric<>'cards' or target.ends_at>clock_timestamp()
   or exists(select 1 from public.paid_tournament_predictions where tournament_id=target.id and status<>'settled')
  then raise exception 'O torneio de cartões ainda não está encerrado ou seus resultados estão pendentes.'; end if;
  delete from public.automatic_result_observations where target_key like 'tournament:'||target.id::text||':%';
  delete from public.tournament_bot_pick_log where tournament_id=target.id;
  delete from public.admin_tournament_pick_corrections where tournament_id=target.id;
  delete from public.paid_tournament_champions where tournament_id=target.id;
  delete from public.paid_tournament_picks where tournament_id=target.id;
  delete from public.paid_tournament_entries where tournament_id=target.id;
  delete from public.paid_tournament_predictions where tournament_id=target.id;
  delete from public.infinitepay_orders where tournament_id=target.id;
  delete from public.paid_tournaments where id=target.id;
 end if;
end $$;

notify pgrst,'reload schema';
commit;
