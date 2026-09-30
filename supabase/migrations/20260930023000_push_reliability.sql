create or replace function public.set_my_push_settings(p_available boolean,p_reminder boolean,p_result boolean)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id();
begin
  if auth.uid() is null or target is null then raise exception 'Entre para configurar os avisos.'; end if;
  if p_available is null or p_reminder is null or p_result is null then raise exception 'Preferências inválidas.'; end if;
  insert into public.push_preferences(profile_id,available,reminder,result)
    values(target,p_available,p_reminder,p_result)
    on conflict(profile_id) do update set available=excluded.available,reminder=excluded.reminder,
      result=excluded.result,updated_at=now();
  return jsonb_build_object('available',p_available,'reminder',p_reminder,'result',p_result);
end;
$$;

create or replace function public.claim_push_delivery(p_kind text,p_day date,p_slot smallint,p_endpoint text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare claimed text;
begin
  if not exists(select 1 from public.get_push_recipients(p_kind,p_day,p_slot) r where r.endpoint=p_endpoint) then return false; end if;
  delete from public.push_deliveries where kind=p_kind and day_id=p_day and slot=p_slot
    and endpoint=p_endpoint and delivered_at is null and claimed_at<now()-interval '5 minutes';
  insert into public.push_deliveries(kind,day_id,slot,endpoint) values(p_kind,p_day,p_slot,p_endpoint)
    on conflict do nothing returning endpoint into claimed;
  return claimed is not null;
end;
$$;

create index push_deliveries_day_idx on public.push_deliveries(day_id);
select cron.schedule('push-delivery-cleanup','0 5 * * *',
  $job$delete from public.push_deliveries where day_id<timezone('America/Sao_Paulo',now())::date-35;$job$);
