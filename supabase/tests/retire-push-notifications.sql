do $$
declare retired record; role_name text;
begin
  if exists(select 1 from public.push_preferences where available or reminder or result) then
    raise exception 'Notification preferences remain enabled';
  end if;
  if exists(select 1 from cron.job where jobname in ('push-palpites-five-minutes','push-delivery-cleanup')) then
    raise exception 'Notification jobs remain installed';
  end if;
  if exists(select 1 from public.get_push_recipients('available',current_date,0::smallint))
     or public.claim_push_delivery('available',current_date,0::smallint,'test-retired') then
    raise exception 'Former dispatch functions still allow delivery';
  end if;
  for retired in select oid from pg_proc where pronamespace='public'::regnamespace and proname in
    ('get_my_push_settings','set_my_push_settings','save_my_push_subscription','remove_my_push_subscription',
     'get_push_games_today','get_push_recipients','claim_push_delivery','finish_push_delivery','remove_dead_push_subscription')
  loop
    foreach role_name in array array['anon','authenticated','service_role'] loop
      if has_function_privilege(role_name,retired.oid,'EXECUTE') then
        raise exception 'Former notification RPC remains accessible to %',role_name;
      end if;
    end loop;
  end loop;
  if (select data from push_retirement_snapshot where name='profiles') is distinct from
      (select jsonb_agg(to_jsonb(p) order by id) from public.public_profiles p)
    or (select data from push_retirement_snapshot where name='picks') is distinct from
      (select jsonb_agg(to_jsonb(p) order by profile_id,prediction_day,slot) from public.picks p)
    or (select data from push_retirement_snapshot where name='other_jobs') is distinct from
      (select jsonb_agg(to_jsonb(j) order by jobid) from cron.job j where jobname not in ('push-palpites-five-minutes','push-delivery-cleanup')) then
    raise exception 'Retirement changed unrelated player data or jobs';
  end if;
end;
$$;
select 'PASS: notifications disabled, access revoked, no recipients; players, picks and other jobs unchanged' as result;
