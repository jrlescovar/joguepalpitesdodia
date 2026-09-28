begin;

-- Remove the obsolete statistic from RPC payloads and pick updates before
-- dropping its column. Preserve each function's signature and permissions.
do $$
declare entry record; definition text;
begin
  for entry in
    select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and p.prokind='f'
      and pg_get_functiondef(p.oid) ilike '%daily_streak_max%'
  loop
    definition := pg_get_functiondef(entry.oid);
    definition := regexp_replace(definition, ',\s*''dailyStreakMax''\s*,\s*(p\.)?daily_streak_max', '', 'g');
    definition := replace(definition, ',daily_streak_max=greatest(daily_streak_max,next_streak)', '');
    if definition ilike '%daily_streak_max%' then
      raise exception 'Unrecognized max daily streak dependency in %', entry.oid::regprocedure;
    end if;
    execute definition;
  end loop;
end;
$$;

alter table public.public_profiles drop column daily_streak_max;
notify pgrst, 'reload schema';
commit;
