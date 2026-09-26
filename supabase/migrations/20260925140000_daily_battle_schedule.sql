-- Supabase databases use UTC. 03:00 UTC is midnight in Brasilia.
create extension if not exists pg_cron;

select cron.schedule(
  'daily-battle-brasilia-midnight',
  '0 3 * * *',
  $job$select public.ensure_daily_battle_round(public.battle_today());$job$
);
