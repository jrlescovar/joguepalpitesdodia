begin;

-- Verified fixtures, CEST converted to Brasilia (UTC-3).
-- https://www.theguardian.com/football/fixtures/2026/Oct/10
-- https://www.theguardian.com/football/fixtures/2026/Oct/11
do $$
begin
 if not exists(select 1 from public.paid_tournaments where id='671f995b-18bf-4c49-a706-caff6e580e19' and enabled and metric='cards'
  and starts_at='2026-10-10T10:00:00-03:00'::timestamptz) then raise exception 'Torneio de cartões inesperado.'; end if;
 if exists(select 1 from public.paid_tournament_predictions where tournament_id='671f995b-18bf-4c49-a706-caff6e580e19') then raise exception 'Já existem partidas; não substituir palpites.'; end if;
end;
$$;

alter table public.paid_tournaments drop constraint paid_tournaments_prediction_count_check;
alter table public.paid_tournaments add constraint paid_tournaments_prediction_count_check check(prediction_count in (20,21));
update public.paid_tournaments set prediction_count=20 where id='671f995b-18bf-4c49-a706-caff6e580e19';

insert into public.paid_tournament_predictions(tournament_id,slot,match_day,home_team,away_team,title,competition,closes_at)
select '671f995b-18bf-4c49-a706-caff6e580e19',slot::smallint,day::date,home_team,away_team,'Quem terá mais cartões?',competition,deadline::timestamptz
from (values
 (1,'2026-10-10','Augsburg','Bayern de Munique','Bundesliga','2026-10-10T10:30:00-03:00'),
 (2,'2026-10-10','Mainz','Bayer Leverkusen','Bundesliga','2026-10-10T10:30:00-03:00'),
 (3,'2026-10-10','Aston Villa','Brentford','Premier League','2026-10-10T11:00:00-03:00'),
 (4,'2026-10-10','Chelsea','Bournemouth','Premier League','2026-10-10T11:00:00-03:00'),
 (5,'2026-10-10','Ipswich Town','Fulham','Premier League','2026-10-10T11:00:00-03:00'),
 (6,'2026-10-10','Sunderland','Brighton','Premier League','2026-10-10T11:00:00-03:00'),
 (7,'2026-10-10','Inter de Milão','Parma','Serie A','2026-10-10T13:00:00-03:00'),
 (8,'2026-10-10','Manchester United','Tottenham','Premier League','2026-10-10T13:30:00-03:00'),
 (9,'2026-10-10','Barcelona','Getafe','La Liga','2026-10-10T13:30:00-03:00'),
 (10,'2026-10-10','Napoli','Frosinone','Serie A','2026-10-10T15:45:00-03:00'),
 (11,'2026-10-11','Crystal Palace','Nottingham Forest','Premier League','2026-10-11T10:00:00-03:00'),
 (12,'2026-10-11','Hull City','Everton','Premier League','2026-10-11T10:00:00-03:00'),
 (13,'2026-10-11','Lazio','Monza','Serie A','2026-10-11T10:00:00-03:00'),
 (14,'2026-10-11','Lecce','Bologna','Serie A','2026-10-11T10:00:00-03:00'),
 (15,'2026-10-11','Colônia','Borussia Mönchengladbach','Bundesliga','2026-10-11T10:30:00-03:00'),
 (16,'2026-10-11','Liverpool','Manchester City','Premier League','2026-10-11T12:30:00-03:00'),
 (17,'2026-10-11','Freiburg','Schalke 04','Bundesliga','2026-10-11T12:30:00-03:00'),
 (18,'2026-10-11','Sassuolo','Milan','Serie A','2026-10-11T13:00:00-03:00'),
 (19,'2026-10-11','Real Betis','Osasuna','La Liga','2026-10-11T13:30:00-03:00'),
 (20,'2026-10-11','Cagliari','Juventus','Serie A','2026-10-11T15:45:00-03:00')
) as fixtures(slot,day,home_team,away_team,competition,deadline);

do $$
declare definition text;
begin
 if (select count(*) from public.paid_tournament_predictions where tournament_id='671f995b-18bf-4c49-a706-caff6e580e19')<>20
  or (select count(distinct match_day) from public.paid_tournament_predictions where tournament_id='671f995b-18bf-4c49-a706-caff6e580e19')<>2
  or exists(select 1 from public.paid_tournament_predictions g join public.paid_tournaments t on t.id=g.tournament_id
   where t.id='671f995b-18bf-4c49-a706-caff6e580e19' and (g.closes_at<t.starts_at or g.closes_at>=t.ends_at))
 then raise exception 'Agenda inválida.'; end if;
 definition:=pg_get_functiondef('public.get_admin_finishing_tournament(uuid)'::regprocedure);
 if position('''id'',tournament.id,''name'',tournament.name' in definition)=0 then raise exception 'Leitura administrativa inesperada.'; end if;
 execute replace(definition,'''id'',tournament.id,''name'',tournament.name','''metric'',tournament.metric,''id'',tournament.id,''name'',tournament.name');
end;
$$;
notify pgrst,'reload schema';
commit;
