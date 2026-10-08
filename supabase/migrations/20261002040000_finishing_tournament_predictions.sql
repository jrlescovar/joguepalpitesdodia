begin;

-- Tournament picks have no relation or triggers on the global predictions/picks.
create table public.paid_tournament_predictions (
 tournament_id uuid not null references public.paid_tournaments(id),
 slot smallint not null check (slot between 1 and 21),
 match_day date not null,
 home_team text not null check (length(home_team) between 1 and 80),
 away_team text not null check (length(away_team) between 1 and 80),
 title text not null default 'Quem terá mais finalizações?',
 competition text not null default 'Liga das Nações',
 closes_at timestamptz not null,
 status text not null default 'open' check (status in ('open','settled')),
 home_shots integer check (home_shots between 0 and 300),
 away_shots integer check (away_shots between 0 and 300),
 winning_option_id text check (winning_option_id in ('home','draw','away')),
 settled_at timestamptz,
 primary key(tournament_id,slot),
 check (home_team<>away_team),
 check (match_day=(closes_at at time zone 'America/Sao_Paulo')::date),
 check ((status='open' and home_shots is null and away_shots is null and winning_option_id is null and settled_at is null)
  or (status='settled' and home_shots is not null and away_shots is not null and settled_at is not null
   and winning_option_id is not null and winning_option_id=case when home_shots>away_shots then 'home' when home_shots<away_shots then 'away' else 'draw' end))
);
create table public.paid_tournament_picks (
 tournament_id uuid not null,
 slot smallint not null,
 profile_id uuid not null,
 option_id text not null check (option_id in ('home','draw','away')),
 created_at timestamptz not null default clock_timestamp(),
 primary key(tournament_id,slot,profile_id),
 foreign key(tournament_id,slot) references public.paid_tournament_predictions(tournament_id,slot),
 foreign key(tournament_id,profile_id) references public.paid_tournament_entries(tournament_id,profile_id) on delete cascade
);
create index paid_tournament_player_picks on public.paid_tournament_picks(tournament_id,profile_id);
alter table public.paid_tournament_predictions enable row level security;
alter table public.paid_tournament_picks enable row level security;
revoke all on public.paid_tournament_predictions,public.paid_tournament_picks from public,anon,authenticated;
grant select,insert,update on public.paid_tournament_predictions,public.paid_tournament_picks to service_role;

-- Fixtures approved in chat. Deadlines are kickoff in Brasilia (UTC-3).
-- Official fixture list: https://www.uefa.com/uefanationsleague/news/02a2-1fea18abbcbc-456e846509e7-1000--2026-27-uefa-nations-league-all-the-league-phase-fixtures-a/
insert into public.paid_tournament_predictions(tournament_id,slot,match_day,home_team,away_team,closes_at)
select '36b34446-4dcf-4d63-8cf3-5ba8ec8d1113',slot::smallint,day::date,home_team,away_team,deadline::timestamptz from (values
 (1,'2026-10-04','Portugal','Noruega','2026-10-04T15:45:00-03:00'),
 (2,'2026-10-04','Holanda','Sérvia','2026-10-04T15:45:00-03:00'),
 (3,'2026-10-04','Grécia','Alemanha','2026-10-04T15:45:00-03:00'),
 (4,'2026-10-04','País de Gales','Dinamarca','2026-10-04T15:45:00-03:00'),
 (5,'2026-10-04','Irlanda','Israel','2026-10-04T15:45:00-03:00'),
 (6,'2026-10-04','Kosovo','Áustria','2026-10-04T13:00:00-03:00'),
 (7,'2026-10-04','Azerbaijão','Lituânia','2026-10-04T10:00:00-03:00'),
 (8,'2026-10-05','França','Bélgica','2026-10-05T15:45:00-03:00'),
 (9,'2026-10-05','Itália','Turquia','2026-10-05T15:45:00-03:00'),
 (10,'2026-10-05','Ucrânia','Hungria','2026-10-05T15:45:00-03:00'),
 (11,'2026-10-05','Bósnia e Herzegovina','Polônia','2026-10-05T15:45:00-03:00'),
 (12,'2026-10-05','Romênia','Suécia','2026-10-05T15:45:00-03:00'),
 (13,'2026-10-05','Irlanda do Norte','Geórgia','2026-10-05T15:45:00-03:00'),
 (14,'2026-10-05','Montenegro','Armênia','2026-10-05T15:45:00-03:00'),
 (15,'2026-10-06','Croácia','Espanha','2026-10-06T15:45:00-03:00'),
 (16,'2026-10-06','Inglaterra','República Tcheca','2026-10-06T15:45:00-03:00'),
 (17,'2026-10-06','Escócia','Eslovênia','2026-10-06T15:45:00-03:00'),
 (18,'2026-10-06','Suíça','Macedônia do Norte','2026-10-06T15:45:00-03:00'),
 (19,'2026-10-06','Moldávia','Eslováquia','2026-10-06T15:45:00-03:00'),
 (20,'2026-10-06','Estônia','Islândia','2026-10-06T15:45:00-03:00'),
 (21,'2026-10-06','Luxemburgo','Bulgária','2026-10-06T15:45:00-03:00')
) as fixtures(slot,day,home_team,away_team,deadline);

-- Read own responses only; other players' selections are never disclosed.
create function public.finishing_tournament_predictions_json(p_tournament_id uuid,p_profile_id uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce(jsonb_agg(jsonb_build_object(
  'slot',g.slot,'dayId',g.match_day,'title',g.title,'homeTeam',g.home_team,'awayTeam',g.away_team,
  'competition',g.competition,'closesAt',g.closes_at,'status',g.status,'winningOptionId',g.winning_option_id,
  'homeShots',g.home_shots,'awayShots',g.away_shots,'myOptionId',p.option_id,
  'myResult',case when p.option_id is null or g.status<>'settled' then null when p.option_id=g.winning_option_id then 'correct' else 'incorrect' end
 ) order by g.slot),'[]'::jsonb)
 from public.paid_tournament_predictions g left join public.paid_tournament_picks p
 on p.tournament_id=g.tournament_id and p.slot=g.slot and p.profile_id=p_profile_id
 where g.tournament_id=p_tournament_id;
$$;
revoke all on function public.finishing_tournament_predictions_json(uuid,uuid) from public,anon,authenticated;

create or replace function public.get_finishing_tournament(p_tournament_id uuid default null)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
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
  'id',tournament.id,'name',tournament.name,'startsAt',tournament.starts_at,'endsAt',tournament.ends_at,
  'entryCents',tournament.entry_cents,'prizeCents',case when tournament.prize_mode='entries' then tournament.entry_cents::bigint*participants else tournament.prize_cents end,
  'predictionCount',tournament.prediction_count,'serverTime',floor(extract(epoch from clock_timestamp())*1000)::bigint,
  'enrolled',enrolled,'registrationOpen',not enrolled and now()<tournament.starts_at,
  'participants',participants,'players',players,'ownRank',own_rank,
  'predictions',case when enrolled then public.finishing_tournament_predictions_json(tournament.id,viewer) else '[]'::jsonb end
 );
end;
$$;
revoke all on function public.get_finishing_tournament(uuid) from public,anon,authenticated;
grant execute on function public.get_finishing_tournament(uuid) to authenticated;

create function public.submit_finishing_tournament_pick(p_tournament_id uuid,p_slot smallint,p_option_id text)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare viewer uuid:=public.own_profile_id(); game public.paid_tournament_predictions; saved text;
begin
 if viewer is null then raise exception 'Entre na sua conta e crie seu perfil.'; end if;
 if p_option_id is null or p_option_id not in ('home','draw','away') then raise exception 'Escolha Casa, Empate ou Fora.'; end if;
 select g.* into game from public.paid_tournament_predictions g join public.paid_tournaments t on t.id=g.tournament_id
 where g.tournament_id=p_tournament_id and g.slot=p_slot and t.enabled for share of g;
 if not found then raise exception 'Palpite do torneio não encontrado.'; end if;
 perform 1 from public.paid_tournament_entries where tournament_id=p_tournament_id and profile_id=viewer for update;
 if not found then raise exception 'Inscreva-se no torneio para palpitar.'; end if;
 select option_id into saved from public.paid_tournament_picks where tournament_id=p_tournament_id and slot=p_slot and profile_id=viewer;
 if found then
  if saved is distinct from p_option_id then raise exception 'Você já confirmou seu palpite nesta partida.'; end if;
  return public.get_finishing_tournament(p_tournament_id);
 end if;
 -- Recheck after acquiring locks, using wall time rather than transaction time.
 if game.status<>'open' or clock_timestamp()>=game.closes_at then raise exception 'O prazo para palpitar terminou.'; end if;
 insert into public.paid_tournament_picks(tournament_id,slot,profile_id,option_id) values(p_tournament_id,p_slot,viewer,p_option_id);
 return public.get_finishing_tournament(p_tournament_id);
end;
$$;
revoke all on function public.submit_finishing_tournament_pick(uuid,smallint,text) from public,anon,authenticated;
grant execute on function public.submit_finishing_tournament_pick(uuid,smallint,text) to authenticated;

create function public.get_admin_finishing_tournament(p_tournament_id uuid default null)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare tournament public.paid_tournaments;
begin
 if not public.is_admin() then raise exception 'Somente o proprietário pode acessar a administração.'; end if;
 select * into tournament from public.paid_tournaments where enabled and (p_tournament_id is null or id=p_tournament_id) order by created_at desc limit 1;
 if not found then return null; end if;
 return jsonb_build_object('id',tournament.id,'name',tournament.name,'serverTime',floor(extract(epoch from clock_timestamp())*1000)::bigint,
  'predictions',public.finishing_tournament_predictions_json(tournament.id,null));
end;
$$;
revoke all on function public.get_admin_finishing_tournament(uuid) from public,anon,authenticated;
grant execute on function public.get_admin_finishing_tournament(uuid) to authenticated;

-- Final shot totals determine the winning option. No global stats or XP writes.
create function public.settle_finishing_tournament_prediction(p_tournament_id uuid,p_slot smallint,p_home_shots integer,p_away_shots integer)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare game public.paid_tournament_predictions; winner text;
begin
 if not public.is_admin() then raise exception 'Somente o proprietário pode concluir os palpites do torneio.'; end if;
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
$$;
revoke all on function public.settle_finishing_tournament_prediction(uuid,smallint,integer,integer) from public,anon,authenticated;
grant execute on function public.settle_finishing_tournament_prediction(uuid,smallint,integer,integer) to authenticated;
notify pgrst,'reload schema';
commit;
