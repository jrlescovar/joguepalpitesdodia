begin;

create table public.admin_tournament_pick_corrections (
 id bigint generated always as identity primary key,
 corrected_at timestamptz not null default clock_timestamp(),
 admin_auth_id uuid not null,
 tournament_id uuid not null,
 profile_id uuid not null,
 slot smallint not null,
 old_option_id text check (old_option_id in ('home','draw','away')),
 new_option_id text not null check (new_option_id in ('home','draw','away')),
 correct_answers_delta integer not null,
 foreign key (tournament_id,slot) references public.paid_tournament_predictions(tournament_id,slot) on delete cascade,
 foreign key (tournament_id,profile_id) references public.paid_tournament_entries(tournament_id,profile_id) on delete cascade
);
alter table public.admin_tournament_pick_corrections enable row level security;
revoke all on public.admin_tournament_pick_corrections from public,anon,authenticated;
revoke all on sequence public.admin_tournament_pick_corrections_id_seq from public,anon,authenticated;

create function public.get_admin_player_tournament_picks(p_profile_id uuid,p_tournament_id uuid default null)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare tournament public.paid_tournaments; hits integer;
begin
 if not public.is_admin() then raise exception 'Somente o proprietário pode consultar palpites de jogadores.'; end if;
 if not exists(select 1 from public.public_profiles where id=p_profile_id) then raise exception 'Jogador não encontrado.'; end if;
 select * into tournament from public.paid_tournaments
 where enabled and (p_tournament_id is null or id=p_tournament_id) order by created_at desc,id limit 1;
 if not found then return null; end if;
 select correct_answers into hits from public.paid_tournament_entries
 where tournament_id=tournament.id and profile_id=p_profile_id;
 return jsonb_build_object('id',tournament.id,'name',tournament.name,'enrolled',hits is not null,
  'correctAnswers',coalesce(hits,0),'predictions',case when hits is not null
   then public.finishing_tournament_predictions_json(tournament.id,p_profile_id) else '[]'::jsonb end);
end;
$$;

create function public.admin_save_tournament_pick(p_profile_id uuid,p_tournament_id uuid,p_slot smallint,p_option_id text,p_expected_option_id text)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare saved text; before_hits integer; after_hits integer;
begin
 if not public.is_admin() or auth.uid() is null then raise exception 'Somente o proprietário pode editar palpites do torneio.'; end if;
 if p_option_id is null or p_option_id not in ('home','draw','away') then raise exception 'Escolha Casa, Empate ou Fora.'; end if;
 -- Same tournament-first lock order as result settlement. This also serializes
 -- concurrent admin edits, and entry locks serialize ordinary player submissions.
 perform 1 from public.paid_tournaments where id=p_tournament_id and enabled for update;
 if not found then raise exception 'Torneio não encontrado.'; end if;
 perform 1 from public.paid_tournament_predictions where tournament_id=p_tournament_id and slot=p_slot for update;
 if not found then raise exception 'Palpite do torneio não encontrado.'; end if;
 select correct_answers into before_hits from public.paid_tournament_entries
 where tournament_id=p_tournament_id and profile_id=p_profile_id for update;
 if not found then raise exception 'Este jogador não está inscrito no torneio.'; end if;
 select option_id into saved from public.paid_tournament_picks
 where tournament_id=p_tournament_id and slot=p_slot and profile_id=p_profile_id;
 -- Replays are harmless; stale forms cannot overwrite a different new choice.
 if saved is not distinct from p_option_id then
  return public.get_admin_player_tournament_picks(p_profile_id,p_tournament_id);
 end if;
 if saved is distinct from p_expected_option_id then raise exception 'O palpite mudou. Recarregue a lista antes de corrigir.'; end if;
 insert into public.paid_tournament_picks(tournament_id,slot,profile_id,option_id)
 values(p_tournament_id,p_slot,p_profile_id,p_option_id)
 on conflict(tournament_id,slot,profile_id) do update set option_id=excluded.option_id;
 select count(*)::integer into after_hits from public.paid_tournament_picks p
 join public.paid_tournament_predictions g on g.tournament_id=p.tournament_id and g.slot=p.slot
 where p.tournament_id=p_tournament_id and p.profile_id=p_profile_id
 and g.status='settled' and p.option_id=g.winning_option_id;
 update public.paid_tournament_entries set correct_answers=after_hits
 where tournament_id=p_tournament_id and profile_id=p_profile_id;
 insert into public.admin_tournament_pick_corrections(admin_auth_id,tournament_id,profile_id,slot,old_option_id,new_option_id,correct_answers_delta)
 values(auth.uid(),p_tournament_id,p_profile_id,p_slot,saved,p_option_id,after_hits-before_hits);
 return public.get_admin_player_tournament_picks(p_profile_id,p_tournament_id);
end;
$$;
revoke all on function public.get_admin_player_tournament_picks(uuid,uuid) from public,anon,authenticated;
revoke all on function public.admin_save_tournament_pick(uuid,uuid,smallint,text,text) from public,anon,authenticated;
grant execute on function public.get_admin_player_tournament_picks(uuid,uuid) to authenticated;
grant execute on function public.admin_save_tournament_pick(uuid,uuid,smallint,text,text) to authenticated;
notify pgrst,'reload schema';
commit;
