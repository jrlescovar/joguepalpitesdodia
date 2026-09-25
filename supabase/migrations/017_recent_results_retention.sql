begin;

-- Keep only today and yesterday (Brasilia) once every game on an older day is settled.
-- Profile totals are durable; individual picks and prediction rows are short-lived.
create or replace function private.prune_old_results()
returns void language plpgsql security definer set search_path = public, private, pg_temp as $$
declare
  cutoff date := timezone('America/Sao_Paulo', now())::date - 1;
  old_days date[];
begin
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

create or replace function private.prune_results_after_publish()
returns trigger language plpgsql security definer set search_path = public, private, pg_temp as $$
begin
  perform private.prune_old_results();
  return null;
end;
$$;
drop trigger if exists prune_results_after_publish on public.predictions;
create trigger prune_results_after_publish
after insert on public.predictions for each statement
execute function private.prune_results_after_publish();

-- Reading the homepage also performs retention, so cleanup happens on the first
-- visit after the day changes even if no new game was published yet.
create or replace function public.get_recent_results()
returns jsonb language plpgsql volatile security definer set search_path = public, private, auth, pg_temp as $$
declare
  today date := timezone('America/Sao_Paulo', now())::date;
  result jsonb;
begin
  perform private.prune_old_results();
  select coalesce(jsonb_agg(public.prediction_json(p) order by p.day_id desc, p.slot asc), '[]'::jsonb)
  into result
  from public.predictions p
  where p.day_id between today - 1 and today and p.status = 'settled';
  return result;
end;
$$;
revoke all on function public.get_recent_results() from public, anon, authenticated;
grant execute on function public.get_recent_results() to authenticated;

notify pgrst, 'reload schema';
commit;
