begin;

create table if not exists public.pass_prepaid (
  profile_id uuid primary key references public.public_profiles(id) on delete cascade,
  ends_at timestamptz not null,
  updated_at timestamptz not null default now()
);
create table if not exists public.pass_prepaid_payments (
  stripe_session_id text primary key,
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  paid_at timestamptz not null default now()
);
alter table public.pass_prepaid enable row level security;
alter table public.pass_prepaid_payments enable row level security;
revoke all on public.pass_prepaid, public.pass_prepaid_payments from public, anon, authenticated;
grant select, insert, update on public.pass_prepaid to service_role;
grant select, insert on public.pass_prepaid_payments to service_role;

create or replace function public.activate_prepaid_pix(p_profile_id uuid, p_session_id text)
returns void language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  if auth.role() <> 'service_role' then raise exception 'Acesso negado.'; end if;
  if p_session_id is null or p_session_id !~ '^cs_' then raise exception 'Pagamento inválido.'; end if;
  perform 1 from public.public_profiles where id = p_profile_id for update;
  if not found then raise exception 'Perfil não encontrado.'; end if;
  insert into public.pass_prepaid_payments(stripe_session_id, profile_id)
  values (p_session_id, p_profile_id)
  on conflict do nothing;
  if not found then return; end if;
  insert into public.pass_prepaid(profile_id, ends_at)
  values (p_profile_id, now() + interval '30 days')
  on conflict (profile_id) do update set
    ends_at = greatest(now(), pass_prepaid.ends_at) + interval '30 days',
    updated_at = now();
end;
$$;
revoke execute on function public.activate_prepaid_pix(uuid,text) from public, anon, authenticated;
grant execute on function public.activate_prepaid_pix(uuid,text) to service_role;

create or replace function public.pass_active(p_profile_id uuid)
returns boolean language sql stable security definer set search_path = public, auth, pg_temp as $$
  select exists(select 1 from public.pass_subscriptions s where s.profile_id = p_profile_id and s.status = 'active' and s.current_period_ends_at > now())
    or exists(select 1 from public.pass_grants g where g.profile_id = p_profile_id and g.revoked_at is null and g.grant_ends_at > now())
    or exists(select 1 from public.pass_prepaid x where x.profile_id = p_profile_id and x.ends_at > now());
$$;
revoke execute on function public.pass_active(uuid) from public, anon, authenticated;

create or replace function public.get_pass_status()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'active', public.pass_active(p.id),
    'status', coalesce(s.status, 'none'),
    'periodEndsAt', s.current_period_ends_at,
    'cancelAtPeriodEnd', coalesce(s.cancel_at_period_end, false),
    'freeActive', coalesce(g.revoked_at is null and g.grant_ends_at > now(), false),
    'freeEndsAt', case when g.revoked_at is null and g.grant_ends_at > now() then g.grant_ends_at else null end,
    'prepaidActive', coalesce(x.ends_at > now(), false),
    'prepaidEndsAt', case when x.ends_at > now() then x.ends_at else null end,
    'borderStyle', case when public.pass_active(p.id) then p.pass_border_style else 'none' end,
    'nameStyle', case when public.pass_active(p.id) then p.pass_name_style else 'none' end
  ) from public.public_profiles p
  left join public.pass_subscriptions s on s.profile_id = p.id
  left join public.pass_grants g on g.profile_id = p.id
  left join public.pass_prepaid x on x.profile_id = p.id
  where p.id = public.own_profile_id();
$$;
revoke execute on function public.get_pass_status() from public, anon, authenticated;
grant execute on function public.get_pass_status() to authenticated;

notify pgrst, 'reload schema';
commit;
