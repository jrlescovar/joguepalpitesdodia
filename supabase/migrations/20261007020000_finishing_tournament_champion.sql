begin;

-- One permanent award per player and tournament, independent of profile totals.
create table public.paid_tournament_champions (
 tournament_id uuid not null,
 profile_id uuid not null,
 rank_points integer not null check(rank_points>0),
 awarded_at timestamptz not null default now(),
 primary key(tournament_id,profile_id),
 foreign key(tournament_id,profile_id) references public.paid_tournament_entries(tournament_id,profile_id)
);
alter table public.paid_tournament_champions enable row level security;
revoke all on public.paid_tournament_champions from public,anon,authenticated;
grant select on public.paid_tournament_champions to service_role;

create function public.grant_paid_tournament_champion(p_tournament_id uuid,p_profile_id uuid,p_rank_points integer)
returns boolean language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare tournament public.paid_tournaments; saved_points integer; hits integer;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'Acesso negado.'; end if;
 if p_rank_points is null or p_rank_points not between 1 and 1000 then raise exception 'Pontuação inválida.'; end if;
 select * into tournament from public.paid_tournaments where id=p_tournament_id for update;
 if not found then raise exception 'Torneio não encontrado.'; end if;
 if tournament.enabled and now()<tournament.ends_at then raise exception 'O torneio ainda não encerrou.'; end if;
 if (select count(*) from public.paid_tournament_predictions where tournament_id=p_tournament_id and status='settled')<>tournament.prediction_count
  or exists(select 1 from public.paid_tournament_predictions where tournament_id=p_tournament_id and status<>'settled') then
  raise exception 'Há resultados do torneio pendentes.';
 end if;
 select correct_answers into hits from public.paid_tournament_entries where tournament_id=p_tournament_id and profile_id=p_profile_id;
 if hits is null or hits<>(select max(correct_answers) from public.paid_tournament_entries where tournament_id=p_tournament_id) then
  raise exception 'O jogador não terminou em primeiro lugar.';
 end if;
 perform 1 from public.public_profiles where id=p_profile_id for update;
 select rank_points into saved_points from public.paid_tournament_champions where tournament_id=p_tournament_id and profile_id=p_profile_id;
 if found then
  if saved_points<>p_rank_points then raise exception 'O prêmio já foi registrado com outra pontuação.'; end if;
  return false;
 end if;
 insert into public.paid_tournament_champions(tournament_id,profile_id,rank_points) values(p_tournament_id,p_profile_id,p_rank_points);
 update public.public_profiles set rank_points=rank_points+p_rank_points,updated_at=now() where id=p_profile_id;
 return true;
end;
$$;
revoke all on function public.grant_paid_tournament_champion(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.grant_paid_tournament_champion(uuid,uuid,integer) to service_role;

do $$
declare definition text; anchor text;
begin
 definition:=pg_get_functiondef('public.get_profile_overview_meta(uuid)'::regprocedure);
 anchor:='''arenaWins'',p.arena_wins';
 if position(anchor in definition)=0 then raise exception 'Definição de medalhas inesperada.'; end if;
 execute replace(definition,anchor,anchor||',''finishingTournamentWins'',(select count(*) from public.paid_tournament_champions c join public.paid_tournaments t on t.id=c.tournament_id where c.profile_id=p.id and t.metric=''shots'')');
 if not exists(select 1 from public.public_profiles where id='2d3d76aa-e9f4-4043-aeaa-9e9abe3f6787' and player_id=1000007) then
  raise exception 'A conta #1000007 não corresponde ao vencedor verificado.';
 end if;
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 perform public.grant_paid_tournament_champion('36b34446-4dcf-4d63-8cf3-5ba8ec8d1113','2d3d76aa-e9f4-4043-aeaa-9e9abe3f6787',100);
end;
$$;

notify pgrst,'reload schema';
commit;
