begin;

-- Match the two-day retention window used by predictions and picks.
-- Battle rewards and win/loss totals are already persisted on profiles.
drop function if exists private.prune_old_daily_battles();
create or replace function private.prune_old_daily_battles(
  p_today date default timezone('America/Sao_Paulo', now())::date
)
returns void language plpgsql security definer set search_path = public, private, pg_temp as $$
declare cutoff date := p_today - 1;
begin
  delete from public.daily_battles
  where day_id < cutoff and result <> 'open';

  delete from public.daily_battle_reserved_pairings r
  where r.day_id < cutoff
    and not exists (
      select 1 from public.daily_battles b
      where b.day_id = r.day_id and b.result = 'open'
    );

  delete from public.daily_battle_rounds r
  where r.day_id < cutoff
    and not exists (select 1 from public.daily_battles b where b.day_id = r.day_id);
end;
$$;
revoke all on function private.prune_old_daily_battles(date) from public, anon, authenticated;

-- The existing two-day results cleanup runs after a prediction is published
-- and whenever recent results are read.
create or replace function private.prune_old_results()
returns void language plpgsql security definer set search_path = public, private, pg_temp as $$
declare
  cutoff date := timezone('America/Sao_Paulo', now())::date - 1;
  old_days date[];
begin
  perform private.prune_old_daily_battles();

  select array_agg(day_id) into old_days
  from (
    select day_id from public.predictions
    where day_id < cutoff
    group by day_id
    having bool_and(status = 'settled')
  ) completed;

  if old_days is null then return; end if;
  delete from public.picks where prediction_day = any(old_days);
  delete from public.predictions where day_id = any(old_days);
end;
$$;
revoke all on function private.prune_old_results() from public, anon, authenticated;

-- Creating a new battle round also clears expired, completed rounds.
create or replace function private.prune_battles_after_round_creation()
returns trigger language plpgsql security definer set search_path = public, private, pg_temp as $$
begin
  perform private.prune_old_daily_battles();
  return null;
end;
$$;
revoke all on function private.prune_battles_after_round_creation() from public, anon, authenticated;
drop trigger if exists prune_battles_after_round_creation on public.daily_battle_rounds;
create trigger prune_battles_after_round_creation
after insert on public.daily_battle_rounds for each statement
execute function private.prune_battles_after_round_creation();

commit;
