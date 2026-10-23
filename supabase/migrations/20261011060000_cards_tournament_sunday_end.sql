begin;
-- Allow a two-day weekend cards tournament to close on its last matchday.
-- The existing three-day shots rule and two-day classic rule are unchanged.
alter table public.paid_tournaments drop constraint paid_tournaments_check;
alter table public.paid_tournaments add constraint paid_tournaments_check check(ends_at>starts_at and (
 (metric='cards' and ((ends_at-interval '1 microsecond') at time zone 'America/Sao_Paulo')::date
  between (starts_at at time zone 'America/Sao_Paulo')::date+1 and (starts_at at time zone 'America/Sao_Paulo')::date+2)
 or (metric<>'cards' and ((ends_at-interval '1 microsecond') at time zone 'America/Sao_Paulo')::date =
  (starts_at at time zone 'America/Sao_Paulo')::date + case when metric='classic' then 1 else 2 end)
));
-- Fixed deadline rather than a relative expression that would extend on replay.
do $$
declare tournament public.paid_tournaments;
begin
 select * into tournament from public.paid_tournaments where id='671f995b-18bf-4c49-a706-caff6e580e19' for update;
 if not found or tournament.metric<>'cards' or tournament.starts_at<>'2026-10-10T10:00:00-03:00'::timestamptz then raise exception 'Torneio de cartões inesperado.';end if;
 if tournament.ends_at not in ('2026-10-13T00:00:00-03:00'::timestamptz,'2026-10-11T18:14:00-03:00'::timestamptz) then raise exception 'Encerramento já foi alterado; confira antes de substituir.';end if;
 if exists(select 1 from public.paid_tournament_predictions where tournament_id=tournament.id and closes_at>='2026-10-11T18:14:00-03:00'::timestamptz) then raise exception 'Há partidas que começariam depois do encerramento.';end if;
 update public.paid_tournaments set ends_at='2026-10-11T18:14:00-03:00' where id=tournament.id;
end $$;
commit;
