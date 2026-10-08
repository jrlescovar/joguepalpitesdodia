begin;

-- Keep the old tournament, picks and payments for audit; only remove its card.
alter table public.paid_tournaments add column metric text not null default 'shots'
 check (metric in ('shots','cards'));

do $$
begin
 if (select count(*) from public.public_profiles where
  (id='3334060e-9857-48f3-b7b0-24e1cb3fd657' and player_id=1000001)
  or (id='38e75f8c-eb50-4a3e-8c3c-91b36fef6c65' and player_id=1000002))<>2 then
  raise exception 'As contas verificadas do jrlescovar e khvicha não correspondem.';
 end if;
end;
$$;

update public.paid_tournaments set enabled=false
where id='36b34446-4dcf-4d63-8cf3-5ba8ec8d1113';

-- Reuse the existing three-day structure; publish no match predictions yet.
insert into public.paid_tournaments(id,name,starts_at,ends_at,entry_cents,prize_cents,prize_mode,metric)
values ('671f995b-18bf-4c49-a706-caff6e580e19','Torneio de Cartões',
 '2026-10-10T10:00:00-03:00','2026-10-13T00:00:00-03:00',333,0,'entries','cards');

-- Explicit admin entries add to the pool without inventing paid receipts.
insert into public.paid_tournament_entries(tournament_id,profile_id,registration_source)
values
 ('671f995b-18bf-4c49-a706-caff6e580e19','3334060e-9857-48f3-b7b0-24e1cb3fd657','admin'),
 ('671f995b-18bf-4c49-a706-caff6e580e19','38e75f8c-eb50-4a3e-8c3c-91b36fef6c65','admin');

do $$
declare definition text; anchor text;
begin
 definition:=pg_get_functiondef('public.get_finishing_tournament(uuid)'::regprocedure);
 anchor:='''id'',tournament.id,''name'',tournament.name';
 if position(anchor in definition)=0 then raise exception 'Definição de leitura de torneio inesperada.'; end if;
 execute replace(definition,anchor,
  '''metric'',tournament.metric,''predictionsPublished'',exists(select 1 from public.paid_tournament_predictions where tournament_id=tournament.id),'
  ||anchor);

 -- The automatic worker currently understands shots only. Card matches must
 -- not be settled using shot totals when they are published in a future step.
 definition:=pg_get_functiondef('public.get_automatic_result_targets()'::regprocedure);
 anchor:='where p.status=''open'' and t.enabled and';
 if position(anchor in definition)=0 then raise exception 'Definição dos alvos automáticos inesperada.'; end if;
 execute replace(definition,anchor,'where p.status=''open'' and t.enabled and t.metric=''shots'' and');
end;
$$;

notify pgrst,'reload schema';
commit;
