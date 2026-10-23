begin;

-- Custom markets retain the existing private tournament picks/ranking/payment flow.
alter table public.paid_tournaments drop constraint paid_tournaments_metric_check;
alter table public.paid_tournaments add constraint paid_tournaments_metric_check check(metric in ('shots','cards','classic','mixed'));
alter table public.paid_tournaments drop constraint paid_tournaments_check;
alter table public.paid_tournaments add constraint paid_tournaments_check check(ends_at>starts_at and (
 (metric='cards' and ((ends_at-interval '1 microsecond') at time zone 'America/Sao_Paulo')::date
  between (starts_at at time zone 'America/Sao_Paulo')::date+1 and (starts_at at time zone 'America/Sao_Paulo')::date+2)
 or (metric<>'cards' and ((ends_at-interval '1 microsecond') at time zone 'America/Sao_Paulo')::date =
  (starts_at at time zone 'America/Sao_Paulo')::date + case when metric='classic' then 1 when metric='mixed' then 0 else 2 end)
));
alter table public.paid_tournament_predictions add column options jsonb;
alter table public.paid_tournament_predictions add column rules text;

-- Canonical choice IDs are opaque identifiers; per-market labels define their meaning.
-- A binary market does not accept the third ID, even via a forged RPC or admin edit.
create function public.validate_tournament_market() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare modality text; option_count integer;
begin
 select metric into modality from public.paid_tournaments where id=new.tournament_id;
 if modality='mixed' then
  if new.options is null or jsonb_typeof(new.options)<>'array' then raise exception 'Informe as opções deste palpite.'; end if;
  option_count:=jsonb_array_length(new.options);
  if option_count not in (2,3) or new.rules is null or length(new.rules) not between 1 and 600 then raise exception 'Opções ou regra inválidas.'; end if;
  if exists(select 1 from jsonb_array_elements(new.options) o where jsonb_typeof(o)<>'object'
    or coalesce(o->>'id','') not in ('home','draw','away') or jsonb_typeof(o->'label') is distinct from 'string'
    or coalesce(length(o->>'label'),0) not between 1 and 60)
   or (select count(distinct o->>'id') from jsonb_array_elements(new.options) o)<>option_count
   or (select count(distinct o->>'label') from jsonb_array_elements(new.options) o)<>option_count
  then raise exception 'Opções inválidas para este palpite.'; end if;
  if new.home_shots is not null or new.away_shots is not null then raise exception 'Apure este palpite pela opção vencedora.'; end if;
  if new.winning_option_id is not null and not exists(select 1 from jsonb_array_elements(new.options) o where o->>'id'=new.winning_option_id)
  then raise exception 'Opção inválida para este palpite.'; end if;
 else
  if new.options is not null or new.rules is not null then raise exception 'Opções personalizadas exigem um torneio de mercados variados.'; end if;
 end if;
 if tg_op='UPDATE' and (new.options is distinct from old.options or new.rules is distinct from old.rules)
  and exists(select 1 from public.paid_tournament_picks where tournament_id=old.tournament_id and slot=old.slot)
 then raise exception 'Não altere as opções ou a regra de um palpite já respondido.'; end if;
 return new;
end;
$$;
revoke all on function public.validate_tournament_market() from public,anon,authenticated;
create trigger validate_paid_tournament_market before insert or update on public.paid_tournament_predictions
for each row execute function public.validate_tournament_market();

create function public.validate_tournament_market_pick() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare choices jsonb;
begin
 select options into choices from public.paid_tournament_predictions where tournament_id=new.tournament_id and slot=new.slot;
 if choices is not null and not exists(select 1 from jsonb_array_elements(choices) o where o->>'id'=new.option_id)
 then raise exception 'Opção inválida para este palpite.'; end if;
 return new;
end;
$$;
revoke all on function public.validate_tournament_market_pick() from public,anon,authenticated;
create trigger validate_paid_tournament_market_pick before insert or update on public.paid_tournament_picks
for each row execute function public.validate_tournament_market_pick();

create or replace function public.finishing_tournament_predictions_json(p_tournament_id uuid,p_profile_id uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce(jsonb_agg(jsonb_build_object(
  'slot',g.slot,'dayId',g.match_day,'title',g.title,'homeTeam',g.home_team,'awayTeam',g.away_team,
  'competition',g.competition,'closesAt',g.closes_at,'status',g.status,'winningOptionId',g.winning_option_id,
  'homeShots',g.home_shots,'awayShots',g.away_shots,'myOptionId',p.option_id,'options',g.options,'rules',g.rules,
  'myResult',case when p.option_id is null or g.status<>'settled' then null when p.option_id=g.winning_option_id then 'correct' else 'incorrect' end
 ) order by g.slot),'[]'::jsonb)
 from public.paid_tournament_predictions g left join public.paid_tournament_picks p
 on p.tournament_id=g.tournament_id and p.slot=g.slot and p.profile_id=p_profile_id
 where g.tournament_id=p_tournament_id;
$$;
revoke all on function public.finishing_tournament_predictions_json(uuid,uuid) from public,anon,authenticated;

-- Start/deadline explicitly requested by the owner, in Brasilia.
insert into public.paid_tournaments(id,name,metric,starts_at,ends_at,entry_cents,prize_cents,prediction_count,prize_mode,enabled)
values('2270fca1-406c-4da0-8582-20c20520a44c','EL CLÁSSICO','mixed',
 '2026-10-25T16:50:00-03:00','2026-10-26T00:00:00-03:00',444,0,20,'entries',true);

insert into public.paid_tournament_predictions(tournament_id,slot,match_day,home_team,away_team,title,competition,closes_at,options,rules)
select '2270fca1-406c-4da0-8582-20c20520a44c',slot::smallint,'2026-10-25'::date,'Barcelona','Real Madrid',title,'La Liga',
 '2026-10-25T16:50:00-03:00'::timestamptz,options,rules from (values
 (1,'Quem vence?','[{"id": "home", "label": "Casa"}, {"id": "draw", "label": "X"}, {"id": "away", "label": "Fora"}]'::jsonb,'Vale o placar final dos 90 minutos e acréscimos.'),
 (2,'Quem terá mais finalizações?','[{"id": "home", "label": "Casa"}, {"id": "draw", "label": "X"}, {"id": "away", "label": "Fora"}]'::jsonb,'Finalizações totais nos 90 minutos e acréscimos, incluindo chutes para fora e bloqueados.'),
 (3,'Quem terá mais chutes ao gol?','[{"id": "home", "label": "Casa"}, {"id": "draw", "label": "X"}, {"id": "away", "label": "Fora"}]'::jsonb,'Chutes no alvo nos 90 minutos e acréscimos.'),
 (4,'Quem receberá mais cartões?','[{"id": "home", "label": "Casa"}, {"id": "draw", "label": "X"}, {"id": "away", "label": "Fora"}]'::jsonb,'Contam amarelos e vermelhos diretos dos jogadores em campo. Segundo amarelo conta como amarelo, sem somar outro vermelho ao total.'),
 (5,'Quem terá mais escanteios?','[{"id": "home", "label": "Casa"}, {"id": "draw", "label": "X"}, {"id": "away", "label": "Fora"}]'::jsonb,'Escanteios nos 90 minutos e acréscimos.'),
 (6,'Quem terá mais impedimentos?','[{"id": "home", "label": "Casa"}, {"id": "draw", "label": "X"}, {"id": "away", "label": "Fora"}]'::jsonb,'Impedimentos assinalados nos 90 minutos e acréscimos.'),
 (7,'Quem cometerá mais faltas?','[{"id": "home", "label": "Casa"}, {"id": "draw", "label": "X"}, {"id": "away", "label": "Fora"}]'::jsonb,'Faltas cometidas nos 90 minutos e acréscimos.'),
 (8,'Mais de 2,5 gols na partida?','[{"id": "home", "label": "Sim"}, {"id": "away", "label": "Não"}]'::jsonb,'Sim: pelo menos 3 gols somados nos 90 minutos e acréscimos.'),
 (9,'Finalizações do Raphinha?','[{"id": "home", "label": "0–2"}, {"id": "draw", "label": "3–4"}, {"id": "away", "label": "5+"}]'::jsonb,'Finalizações totais do jogador nos 90 minutos e acréscimos, incluindo chutes para fora e bloqueados. Se não entrar em campo, conta zero.'),
 (10,'Finalizações do Yamal?','[{"id": "home", "label": "0–2"}, {"id": "draw", "label": "3–4"}, {"id": "away", "label": "5+"}]'::jsonb,'Finalizações totais do jogador nos 90 minutos e acréscimos, incluindo chutes para fora e bloqueados. Se não entrar em campo, conta zero.'),
 (11,'Finalizações do Vini Jr.?','[{"id": "home", "label": "0–2"}, {"id": "draw", "label": "3–4"}, {"id": "away", "label": "5+"}]'::jsonb,'Finalizações totais do jogador nos 90 minutos e acréscimos, incluindo chutes para fora e bloqueados. Se não entrar em campo, conta zero.'),
 (12,'Finalizações do Mbappé?','[{"id": "home", "label": "0–2"}, {"id": "draw", "label": "3–4"}, {"id": "away", "label": "5+"}]'::jsonb,'Finalizações totais do jogador nos 90 minutos e acréscimos, incluindo chutes para fora e bloqueados. Se não entrar em campo, conta zero.'),
 (13,'Defesas do goleiro do Barcelona?','[{"id": "home", "label": "0–2"}, {"id": "draw", "label": "3–5"}, {"id": "away", "label": "6+"}]'::jsonb,'Total de defesas dos goleiros da equipe nos 90 minutos e acréscimos, incluindo substitutos.'),
 (14,'Defesas do goleiro do Real Madrid?','[{"id": "home", "label": "0–2"}, {"id": "draw", "label": "3–5"}, {"id": "away", "label": "6+"}]'::jsonb,'Total de defesas dos goleiros da equipe nos 90 minutos e acréscimos, incluindo substitutos.'),
 (15,'Ambos os times marcam?','[{"id": "home", "label": "Sim"}, {"id": "away", "label": "Não"}]'::jsonb,'Sim: cada equipe marca pelo menos 1 gol nos 90 minutos e acréscimos.'),
 (16,'Quem marca primeiro?','[{"id": "home", "label": "Casa"}, {"id": "draw", "label": "Nenhum"}, {"id": "away", "label": "Fora"}]'::jsonb,'Equipe que marcar o primeiro gol. Nenhum: a partida termina sem gols.'),
 (17,'Quem vence o primeiro tempo?','[{"id": "home", "label": "Casa"}, {"id": "draw", "label": "X"}, {"id": "away", "label": "Fora"}]'::jsonb,'Vale o placar ao fim do primeiro tempo e seus acréscimos.'),
 (18,'Quem terá mais posse de bola?','[{"id": "home", "label": "Casa"}, {"id": "draw", "label": "X"}, {"id": "away", "label": "Fora"}]'::jsonb,'Percentual de posse de bola nos 90 minutos e acréscimos. X: percentuais iguais.'),
 (19,'Vai ter cartão vermelho?','[{"id": "home", "label": "Sim"}, {"id": "away", "label": "Não"}]'::jsonb,'Sim: jogador em campo expulso por vermelho direto ou segundo amarelo nos 90 minutos e acréscimos.'),
 (20,'Vai ter mais de 5,5 cartões?','[{"id": "home", "label": "Sim"}, {"id": "away", "label": "Não"}]'::jsonb,'Sim: pelo menos 6 cartões somados nos 90 minutos e acréscimos. Contam amarelos e vermelhos diretos dos jogadores em campo. Segundo amarelo conta como amarelo, sem somar outro vermelho ao total.')
) as markets(slot,title,options,rules);

notify pgrst,'reload schema';
commit;
