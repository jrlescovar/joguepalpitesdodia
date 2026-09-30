create table public.push_preferences (
  profile_id uuid primary key references public.public_profiles(id) on delete cascade,
  available boolean not null default false,
  reminder boolean not null default false,
  result boolean not null default false,
  updated_at timestamptz not null default now()
);
create table public.push_subscriptions (
  endpoint text primary key,
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  p256dh text not null,
  auth_secret text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index push_subscriptions_profile_idx on public.push_subscriptions(profile_id);
create table public.push_deliveries (
  kind text not null check (kind in ('available','reminder','result')),
  day_id date not null,
  slot smallint not null,
  endpoint text not null,
  claimed_at timestamptz not null default now(),
  delivered_at timestamptz,
  primary key(kind,day_id,slot,endpoint)
);
create index push_deliveries_pending_idx on public.push_deliveries(claimed_at) where delivered_at is null;

alter table public.push_preferences enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.push_deliveries enable row level security;
revoke all on public.push_preferences,public.push_subscriptions,public.push_deliveries from public,anon,authenticated;

create function public.get_my_push_settings() returns jsonb language plpgsql stable security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id();
begin
  if auth.uid() is null or target is null then raise exception 'Entre para configurar os avisos.'; end if;
  return coalesce((select jsonb_build_object('available',available,'reminder',reminder,'result',result)
    from public.push_preferences where profile_id=target),
    jsonb_build_object('available',false,'reminder',false,'result',false));
end;
$$;

create function public.set_my_push_settings(p_available boolean,p_reminder boolean,p_result boolean)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id();
begin
  if auth.uid() is null or target is null then raise exception 'Entre para configurar os avisos.'; end if;
  if p_available is null or p_reminder is null or p_result is null then raise exception 'Preferências inválidas.'; end if;
  insert into public.push_preferences(profile_id,available,reminder,result)
    values(target,p_available,p_reminder,p_result)
    on conflict(profile_id) do update set available=excluded.available,reminder=excluded.reminder,
      result=excluded.result,updated_at=now();
  return public.get_my_push_settings();
end;
$$;

create function public.save_my_push_subscription(p_endpoint text,p_p256dh text,p_auth text)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id();
begin
  if auth.uid() is null or target is null then raise exception 'Entre para ativar os avisos.'; end if;
  if length(coalesce(p_endpoint,''))>2048 or p_endpoint !~* '^https://(fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|web\.push\.apple\.com)/'
    or length(coalesce(p_p256dh,'')) not between 40 and 512 or length(coalesce(p_auth,'')) not between 10 and 256
    then raise exception 'Inscrição de notificações inválida.'; end if;
  insert into public.push_subscriptions(endpoint,profile_id,p256dh,auth_secret)
    values(p_endpoint,target,p_p256dh,p_auth)
    on conflict(endpoint) do update set profile_id=excluded.profile_id,p256dh=excluded.p256dh,
      auth_secret=excluded.auth_secret,updated_at=now();
end;
$$;

create function public.remove_my_push_subscription(p_endpoint text)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id();
begin
  if auth.uid() is null or target is null then return; end if;
  delete from public.push_subscriptions where endpoint=p_endpoint and profile_id=target;
end;
$$;

create function public.get_push_recipients(p_kind text,p_day date,p_slot smallint)
returns table(profile_id uuid,endpoint text,p256dh text,auth_secret text)
language sql stable security definer set search_path=public,pg_temp as $$
  select s.profile_id,s.endpoint,s.p256dh,s.auth_secret
  from public.predictions g
  join public.push_subscriptions s on true
  join public.push_preferences pref on pref.profile_id=s.profile_id
  where g.day_id=p_day and g.slot=p_slot
    and ((p_kind='available' and pref.available and g.status='open' and g.closes_at>now())
      or (p_kind='reminder' and pref.reminder and g.status='open' and g.closes_at>now() and g.closes_at<=now()+interval '30 minutes')
      or (p_kind='result' and pref.result and g.status='settled'))
    and (p_kind='result' or not exists (select 1 from public.picks k
      where k.profile_id=s.profile_id and k.prediction_day=p_day and k.slot=p_slot));
$$;

create function public.claim_push_delivery(p_kind text,p_day date,p_slot smallint,p_endpoint text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare claimed text;
begin
  if not exists(select 1 from public.get_push_recipients(p_kind,p_day,p_slot) r where r.endpoint=p_endpoint) then return false; end if;
  insert into public.push_deliveries(kind,day_id,slot,endpoint) values(p_kind,p_day,p_slot,p_endpoint)
    on conflict do nothing returning endpoint into claimed;
  return claimed is not null;
end;
$$;

create function public.finish_push_delivery(p_kind text,p_day date,p_slot smallint,p_endpoint text,p_sent boolean)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_sent then
    update public.push_deliveries set delivered_at=now()
      where kind=p_kind and day_id=p_day and slot=p_slot and endpoint=p_endpoint;
  else
    delete from public.push_deliveries where kind=p_kind and day_id=p_day and slot=p_slot
      and endpoint=p_endpoint and delivered_at is null;
  end if;
end;
$$;

create function public.remove_dead_push_subscription(p_endpoint text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  delete from public.push_subscriptions where endpoint=p_endpoint;
  delete from public.push_deliveries where endpoint=p_endpoint;
end;
$$;

revoke all on function public.get_my_push_settings(),public.set_my_push_settings(boolean,boolean,boolean),
  public.save_my_push_subscription(text,text,text),public.remove_my_push_subscription(text),
  public.get_push_recipients(text,date,smallint),public.claim_push_delivery(text,date,smallint,text),
  public.finish_push_delivery(text,date,smallint,text,boolean),public.remove_dead_push_subscription(text)
  from public,anon,authenticated;
grant execute on function public.get_my_push_settings(),public.set_my_push_settings(boolean,boolean,boolean),
  public.save_my_push_subscription(text,text,text),public.remove_my_push_subscription(text) to authenticated;
grant execute on function public.get_push_recipients(text,date,smallint),
  public.claim_push_delivery(text,date,smallint,text),public.finish_push_delivery(text,date,smallint,text,boolean),
  public.remove_dead_push_subscription(text) to service_role;
