-- Add the same global position used by Ranking Global to each fighter.
create or replace function public.battle_rank_meta(p_profile_id uuid)
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'rankPoints', p.rank_points,
    'globalPosition', 1 + (
      select count(*) from public.public_profiles ahead
      where ahead.rank_points > p.rank_points
        or (ahead.rank_points = p.rank_points and ahead.player_id < p.player_id)
    )
  )
  from public.public_profiles p where p.id = p_profile_id;
$$;

revoke execute on function public.battle_rank_meta(uuid) from public, anon, authenticated;

create or replace function public.get_my_daily_battle_with_ranks()
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare payload jsonb; candidates jsonb;
begin
  payload := public.get_my_daily_battle();
  if jsonb_typeof(payload->'me') = 'object' then
    payload := jsonb_set(payload, '{me}', payload->'me' || public.battle_rank_meta((payload#>>'{me,uid}')::uuid));
  end if;
  if jsonb_typeof(payload->'opponent') = 'object' then
    payload := jsonb_set(payload, '{opponent}', payload->'opponent' || public.battle_rank_meta((payload#>>'{opponent,uid}')::uuid));
  end if;
  select coalesce(jsonb_agg(candidate.value || public.battle_rank_meta((candidate.value->>'uid')::uuid) order by candidate.ordinality), '[]'::jsonb)
    into candidates
    from jsonb_array_elements(coalesce(payload->'reelCandidates', '[]'::jsonb)) with ordinality as candidate(value, ordinality);
  return jsonb_set(payload, '{reelCandidates}', candidates, true);
end;
$$;

revoke execute on function public.get_my_daily_battle_with_ranks() from public, anon, authenticated;
grant execute on function public.get_my_daily_battle_with_ranks() to authenticated;

notify pgrst, 'reload schema';
