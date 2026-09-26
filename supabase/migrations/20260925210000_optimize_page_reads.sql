begin;

-- Session, profile and streak reference arrive together on initial load/refresh.
create or replace function public.get_player_bootstrap()
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  return jsonb_build_object(
    'session', public.get_session(),
    'profile', public.get_or_claim_profile(),
    'lastClosedPrediction', public.get_last_closed_prediction()
  );
end;
$$;
revoke execute on function public.get_player_bootstrap() from public, anon, authenticated;
grant execute on function public.get_player_bootstrap() to authenticated;

-- One small read supplies the public battle counters and global place on a profile.
create or replace function public.get_profile_overview_meta(p_profile_id uuid)
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'globalPosition', 1 + (
      select count(*) from public.public_profiles ahead
      where ahead.rank_points > p.rank_points
        or (ahead.rank_points = p.rank_points and ahead.player_id < p.player_id)
    ),
    'battleStats', jsonb_build_object('wins', p.battle_wins, 'losses', p.battle_losses, 'draws', p.battle_draws)
  )
  from public.public_profiles p where p.id = p_profile_id;
$$;
revoke execute on function public.get_profile_overview_meta(uuid) from public, anon, authenticated;
grant execute on function public.get_profile_overview_meta(uuid) to authenticated;

-- Keep the list and the viewer's place in one ranking response per page.
create or replace function public.get_global_ranking_page()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'players', public.get_global_rank_top10(),
    'ownRank', public.get_my_global_rank()
  );
$$;
revoke execute on function public.get_global_ranking_page() from public, anon, authenticated;
grant execute on function public.get_global_ranking_page() to authenticated;

create or replace function public.get_tournament_ranking_page()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'players', public.get_ranking_top10(),
    'ownRank', public.get_my_rank()
  );
$$;
revoke execute on function public.get_tournament_ranking_page() from public, anon, authenticated;
grant execute on function public.get_tournament_ranking_page() to authenticated;

-- Reel fighters never display a rank. Calculate positions only for the two players.
create or replace function public.get_my_daily_battle_with_ranks()
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare payload jsonb;
begin
  payload := public.get_my_daily_battle();
  if jsonb_typeof(payload->'me') = 'object' then
    payload := jsonb_set(payload, '{me}', payload->'me' || public.battle_rank_meta((payload#>>'{me,uid}')::uuid));
  end if;
  if jsonb_typeof(payload->'opponent') = 'object' then
    payload := jsonb_set(payload, '{opponent}', payload->'opponent' || public.battle_rank_meta((payload#>>'{opponent,uid}')::uuid));
  end if;
  return payload;
end;
$$;
revoke execute on function public.get_my_daily_battle_with_ranks() from public, anon, authenticated;
grant execute on function public.get_my_daily_battle_with_ranks() to authenticated;

notify pgrst, 'reload schema';
commit;
