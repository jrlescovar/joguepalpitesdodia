begin;
-- Payments confirmed by the owner outside the automated checkout.
create table public.supporter_manual_paid_periods (
 profile_id uuid not null references public.public_profiles(id) on delete cascade,
 payment_reference text not null,
 months integer not null check (months > 0),
 recorded_at timestamptz not null default now(),
 primary key (profile_id,payment_reference)
);
alter table public.supporter_manual_paid_periods enable row level security;
revoke all on public.supporter_manual_paid_periods from public,anon,authenticated;
create or replace function public.get_profile_overview_meta(p_profile_id uuid)
returns jsonb language sql volatile security definer set search_path=public,auth,pg_temp as $$
 select jsonb_build_object(
  'globalPosition',1+(select count(*) from public.public_profiles ahead where ahead.rank_points>p.rank_points or (ahead.rank_points=p.rank_points and ahead.player_id<p.player_id)),
  'battleStats',jsonb_build_object('wins',p.battle_wins,'losses',p.battle_losses,'draws',p.battle_draws),
  'arenaWins',p.arena_wins,
  'supporterMonths',(select count(*) from public.pass_box_rewards r where r.profile_id=p.id and r.source in ('subscription','pix'))+(select coalesce(sum(m.months),0) from public.supporter_manual_paid_periods m where m.profile_id=p.id)
 ) from public.public_profiles p where p.id=p_profile_id;
$$;
revoke execute on function public.get_profile_overview_meta(uuid) from public,anon,authenticated;
grant execute on function public.get_profile_overview_meta(uuid) to authenticated;
commit;
