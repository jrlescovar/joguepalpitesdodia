begin;

-- Three match days remain Sunday through Tuesday. Starting later on Sunday
-- must not push the existing Tuesday-night closing time into Wednesday.
alter table public.paid_tournaments drop constraint paid_tournaments_check;
alter table public.paid_tournaments add constraint paid_tournaments_check check (
  ends_at > starts_at
  and ((ends_at - interval '1 microsecond') at time zone 'America/Sao_Paulo')::date
    = (starts_at at time zone 'America/Sao_Paulo')::date + 2
);

do $$
declare target public.paid_tournaments;
begin
  select * into target from public.paid_tournaments
  where id='36b34446-4dcf-4d63-8cf3-5ba8ec8d1113' for update;
  if not found then raise exception 'Torneio de Finalização não encontrado.'; end if;
  if target.starts_at not in ('2026-10-04T00:00:00-03:00'::timestamptz,'2026-10-04T10:00:00-03:00'::timestamptz)
     or target.ends_at<>'2026-10-07T00:00:00-03:00'::timestamptz then
    raise exception 'O calendário do torneio mudou; confira antes de atualizar.';
  end if;
  if exists(select 1 from public.paid_tournament_predictions where tournament_id=target.id
    and closes_at<'2026-10-04T10:00:00-03:00'::timestamptz) then
    raise exception 'Há uma partida com prazo anterior ao novo início.';
  end if;
  update public.paid_tournaments set starts_at='2026-10-04T10:00:00-03:00' where id=target.id;
end;
$$;

notify pgrst,'reload schema';
commit;
