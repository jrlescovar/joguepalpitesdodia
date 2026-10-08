begin;

-- Retire notification delivery without changing players, predictions or picks.
update public.push_preferences set available=false,reminder=false,result=false,updated_at=now()
where available or reminder or result;

do $$
declare job_id bigint;
begin
  for job_id in select jobid from cron.job
    where jobname in ('push-palpites-five-minutes','push-delivery-cleanup')
  loop
    perform cron.unschedule(job_id);
  end loop;
end;
$$;

-- An already-running older dispatcher must not obtain any more recipients.
create or replace function public.get_push_recipients(p_kind text,p_day date,p_slot smallint)
returns table(profile_id uuid,endpoint text,p256dh text,auth_secret text)
language sql stable security definer set search_path=public,pg_temp as $$
  select null::uuid,null::text,null::text,null::text where false;
$$;
create or replace function public.claim_push_delivery(p_kind text,p_day date,p_slot smallint,p_endpoint text)
returns boolean language sql security definer set search_path=public,pg_temp as $$
  select false;
$$;

-- Keep private records, but remove all client and service access to the old API.
revoke all on function public.get_my_push_settings(),public.set_my_push_settings(boolean,boolean,boolean),
  public.save_my_push_subscription(text,text,text),public.remove_my_push_subscription(text),
  public.get_push_games_today(),public.get_push_recipients(text,date,smallint),
  public.claim_push_delivery(text,date,smallint,text),public.finish_push_delivery(text,date,smallint,text,boolean),
  public.remove_dead_push_subscription(text) from public,anon,authenticated,service_role;
revoke all on public.push_preferences,public.push_subscriptions,public.push_deliveries
  from public,anon,authenticated,service_role;

notify pgrst,'reload schema';
commit;
