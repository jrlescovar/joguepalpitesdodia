begin;

-- Keep recorded shot totals consistent, while allowing the owner to apure only
-- the winning option. Do not fabricate shot totals for a direct selection.
alter table public.paid_tournament_predictions drop constraint paid_tournament_predictions_check2;
alter table public.paid_tournament_predictions add constraint paid_tournament_predictions_result_check check (
 (status='open' and home_shots is null and away_shots is null and winning_option_id is null and settled_at is null)
 or (status='settled' and settled_at is not null and winning_option_id is not null and (
  (home_shots is null and away_shots is null)
  or (home_shots is not null and away_shots is not null and winning_option_id=
   case when home_shots>away_shots then 'home' when home_shots<away_shots then 'away' else 'draw' end)
 ))
);

create function public.settle_finishing_tournament_winner(p_tournament_id uuid,p_slot smallint,p_winning_option_id text)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare game public.paid_tournament_predictions;
begin
 if not public.is_admin() then raise exception 'Somente o proprietário pode concluir os palpites do torneio.'; end if;
 if p_winning_option_id is null or p_winning_option_id not in ('home','draw','away') then raise exception 'Selecione um resultado válido.'; end if;
 -- Same lock order as settlement by totals, preserving concurrent acertos.
 perform 1 from public.paid_tournaments where id=p_tournament_id for update;
 select * into game from public.paid_tournament_predictions where tournament_id=p_tournament_id and slot=p_slot for update;
 if not found then raise exception 'Palpite do torneio não encontrado.'; end if;
 if game.status='settled' then
  if game.winning_option_id is distinct from p_winning_option_id then raise exception 'Este resultado já foi confirmado.'; end if;
  return public.get_admin_finishing_tournament(p_tournament_id);
 end if;
 if clock_timestamp()<game.closes_at then raise exception 'A partida ainda não começou.'; end if;
 update public.paid_tournament_predictions set status='settled',winning_option_id=p_winning_option_id,settled_at=clock_timestamp()
 where tournament_id=p_tournament_id and slot=p_slot;
 update public.paid_tournament_entries e set correct_answers=(
  select count(*)::integer from public.paid_tournament_picks p join public.paid_tournament_predictions g
   on g.tournament_id=p.tournament_id and g.slot=p.slot
  where p.tournament_id=e.tournament_id and p.profile_id=e.profile_id and g.status='settled' and p.option_id=g.winning_option_id
 ) where e.tournament_id=p_tournament_id;
 return public.get_admin_finishing_tournament(p_tournament_id);
end;
$$;
revoke all on function public.settle_finishing_tournament_winner(uuid,smallint,text) from public,anon,authenticated;
grant execute on function public.settle_finishing_tournament_winner(uuid,smallint,text) to authenticated;
notify pgrst,'reload schema';
commit;
