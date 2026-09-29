begin;
alter table public.public_profiles add column arena_wins integer not null default 0 check(arena_wins>=0);
-- The crown proves one older win even if that round aged out of the short history.
update public.public_profiles p set arena_wins=greatest(
 (select count(*)::integer from public.arena_rounds r where r.status='finished' and r.winner_id=p.id),
 case when exists(select 1 from public.arena_crown c where c.profile_id=p.id) then 1 else 0 end);
create function public.record_arena_win() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if old.status='finished' and (new.winner_id is distinct from old.winner_id or new.status<>old.status) then
  raise exception 'O campeão de uma Arena encerrada não pode mudar.';
 end if;
 if old.status<>'finished' and new.status='finished' and new.winner_id is not null then
  update public.public_profiles set arena_wins=arena_wins+1 where id=new.winner_id;
 end if;
 return new;
end;$$;
create trigger record_arena_win before update of status,winner_id on public.arena_rounds for each row execute function public.record_arena_win();
revoke all on function public.record_arena_win() from public,anon,authenticated;
create or replace function public.get_profile_overview_meta(p_profile_id uuid)
returns jsonb language sql volatile security definer set search_path=public,auth,pg_temp as $$
 select jsonb_build_object(
  'globalPosition',1+(select count(*) from public.public_profiles ahead where ahead.rank_points>p.rank_points or (ahead.rank_points=p.rank_points and ahead.player_id<p.player_id)),
  'battleStats',jsonb_build_object('wins',p.battle_wins,'losses',p.battle_losses,'draws',p.battle_draws),
  'arenaWins',p.arena_wins
 ) from public.public_profiles p where p.id=p_profile_id;
$$;
revoke execute on function public.get_profile_overview_meta(uuid) from public,anon,authenticated;
grant execute on function public.get_profile_overview_meta(uuid) to authenticated;
commit;
