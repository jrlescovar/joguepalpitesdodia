begin;

update public.push_preferences set reminder=false,result=false,updated_at=now()
where reminder or result;

create or replace function public.get_my_push_settings()
returns jsonb language plpgsql stable security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id();
begin
  if auth.uid() is null or target is null then raise exception 'Entre para configurar os avisos.'; end if;
  return coalesce((select jsonb_build_object('available',available)
    from public.push_preferences where profile_id=target),jsonb_build_object('available',false));
end;
$$;

create or replace function public.set_my_push_settings(p_available boolean,p_reminder boolean,p_result boolean)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id();
begin
  if auth.uid() is null or target is null then raise exception 'Entre para configurar os avisos.'; end if;
  if p_available is null then raise exception 'Preferência inválida.'; end if;
  insert into public.push_preferences(profile_id,available,reminder,result)
    values(target,p_available,false,false)
    on conflict(profile_id) do update set available=excluded.available,reminder=false,
      result=false,updated_at=now();
  return jsonb_build_object('available',p_available);
end;
$$;

create or replace function public.get_push_recipients(p_kind text,p_day date,p_slot smallint)
returns table(profile_id uuid,endpoint text,p256dh text,auth_secret text)
language sql stable security definer set search_path=public,pg_temp as $$
  select s.profile_id,s.endpoint,s.p256dh,s.auth_secret
  from public.predictions g
  join public.push_subscriptions s on true
  join public.push_preferences pref on pref.profile_id=s.profile_id
  where p_kind='available' and g.day_id=p_day and g.slot=p_slot
    and pref.available and g.status='open' and g.closes_at>now()
    and not exists (select 1 from public.picks k
      where k.profile_id=s.profile_id and k.prediction_day=p_day and k.slot=p_slot);
$$;

do $$
declare job_id bigint;
begin
  select jobid into job_id from cron.job where jobname='push-palpites-five-minutes';
  if job_id is not null then perform cron.unschedule(job_id); end if;
end;
$$;

notify pgrst,'reload schema';
commit;
