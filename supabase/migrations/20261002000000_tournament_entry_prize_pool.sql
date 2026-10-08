begin;
-- The pool now grows by one entry fee for each registered participant.
alter table public.paid_tournaments add column prize_mode text not null default 'fixed'
 check (prize_mode in ('fixed','entries'));
alter table public.paid_tournaments drop constraint paid_tournaments_prize_cents_check;
alter table public.paid_tournaments add constraint paid_tournaments_prize_cents_check check (prize_cents>=0);
update public.paid_tournaments set prize_mode='entries',prize_cents=0
where id='36b34446-4dcf-4d63-8cf3-5ba8ec8d1113';

-- Admin enrollment is explicit; it never fabricates a gateway payment or receipt.
alter table public.paid_tournament_entries add column registration_source text not null default 'payment'
 check (registration_source in ('payment','admin'));
alter table public.paid_tournament_entries alter column order_id drop not null;
alter table public.paid_tournament_entries add constraint paid_tournament_entry_source_check check (
 (registration_source='payment' and order_id is not null)
 or (registration_source='admin' and order_id is null)
);
do $$
begin
 if (select count(*) from public.public_profiles where
  (id='3334060e-9857-48f3-b7b0-24e1cb3fd657' and player_id=1000001)
  or (id='38e75f8c-eb50-4a3e-8c3c-91b36fef6c65' and player_id=1000002)
  or (id='9c99f617-23be-44fb-9438-cc1566478c18' and player_id=1000008))<>3 then
  raise exception 'The requested tournament players do not match the verified accounts';
 end if;
end;
$$;
-- Requested accounts: jrlescovar, khvicha, NicoTheGoat.
insert into public.paid_tournament_entries(tournament_id,profile_id,registration_source)
select '36b34446-4dcf-4d63-8cf3-5ba8ec8d1113',id,'admin' from public.public_profiles
where id in ('3334060e-9857-48f3-b7b0-24e1cb3fd657','38e75f8c-eb50-4a3e-8c3c-91b36fef6c65','9c99f617-23be-44fb-9438-cc1566478c18')
on conflict(tournament_id,profile_id) do nothing;

do $$
declare definition text; anchor text;
begin
 definition:=pg_get_functiondef('public.get_finishing_tournament(uuid)'::regprocedure);
 anchor:='''prizeCents'',tournament.prize_cents';
 if position(anchor in definition)=0 then raise exception 'Unexpected tournament prize definition'; end if;
 definition:=replace(definition,anchor,
  '''prizeCents'',case when tournament.prize_mode=''entries'' then tournament.entry_cents::bigint*participants else tournament.prize_cents end');
 execute definition;
end;
$$;
revoke all on function public.get_finishing_tournament(uuid) from public,anon,authenticated;
grant execute on function public.get_finishing_tournament(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
