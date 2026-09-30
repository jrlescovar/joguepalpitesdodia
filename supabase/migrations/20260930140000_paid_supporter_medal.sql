begin;
create or replace function public.get_profile_overview_meta(p_profile_id uuid)
returns jsonb language sql volatile security definer set search_path=public,auth,pg_temp as $$
 select jsonb_build_object(
  'globalPosition',1+(select count(*) from public.public_profiles ahead where ahead.rank_points>p.rank_points or (ahead.rank_points=p.rank_points and ahead.player_id<p.player_id)),
  'battleStats',jsonb_build_object('wins',p.battle_wins,'losses',p.battle_losses,'draws',p.battle_draws),
  'arenaWins',p.arena_wins,
  'supporterMonths',(select count(*) from public.pass_box_rewards r where r.profile_id=p.id and r.source in ('subscription','pix'))
 ) from public.public_profiles p where p.id=p_profile_id;
$$;
revoke execute on function public.get_profile_overview_meta(uuid) from public,anon,authenticated;
grant execute on function public.get_profile_overview_meta(uuid) to authenticated;
commit;
