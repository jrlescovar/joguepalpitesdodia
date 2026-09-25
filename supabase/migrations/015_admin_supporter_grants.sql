begin;

-- A free admin grant is separate from Stripe billing. Expiry is checked at
-- read time, so access ends even if no scheduled job runs.
create table if not exists public.pass_grants (
  profile_id uuid primary key references public.public_profiles(id) on delete cascade,
  grant_ends_at timestamptz not null,
  revoked_at timestamptz,
  granted_by uuid,
  updated_at timestamptz not null default now()
);
alter table public.pass_grants enable row level security;
revoke all on public.pass_grants from public, anon, authenticated;

create or replace function public.pass_active(p_profile_id uuid)
returns boolean language sql stable security definer set search_path = public, auth, pg_temp as $$
  select
    exists(select 1 from public.pass_subscriptions s
      where s.profile_id = p_profile_id and s.status = 'active'
        and s.current_period_ends_at > now())
    or exists(select 1 from public.pass_grants g
      where g.profile_id = p_profile_id and g.revoked_at is null
        and g.grant_ends_at > now());
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
    'borderStyle', case when public.pass_active(p.id) then p.pass_border_style else 'none' end,
    'nameStyle', case when public.pass_active(p.id) then p.pass_name_style else 'none' end
  ) from public.public_profiles p
  left join public.pass_subscriptions s on s.profile_id = p.id
  left join public.pass_grants g on g.profile_id = p.id
  where p.id = public.own_profile_id();
$$;
revoke execute on function public.get_pass_status() from public, anon, authenticated;
grant execute on function public.get_pass_status() to authenticated;

create or replace function public.admin_get_pass_grant(p_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode acessar o Premium.'; end if;
  if not exists(select 1 from public.public_profiles where id = p_profile_id) then
    raise exception 'Jogador não encontrado.';
  end if;
  return (
    select jsonb_build_object(
      'freeActive', coalesce(g.revoked_at is null and g.grant_ends_at > now(), false),
      'freeEndsAt', case when g.revoked_at is null and g.grant_ends_at > now() then g.grant_ends_at else null end,
      'paidActive', coalesce(s.status = 'active' and s.current_period_ends_at > now(), false),
      'paidEndsAt', s.current_period_ends_at
    ) from public.public_profiles p
    left join public.pass_grants g on g.profile_id = p.id
    left join public.pass_subscriptions s on s.profile_id = p.id
    where p.id = p_profile_id
  );
end;
$$;
revoke execute on function public.admin_get_pass_grant(uuid) from public, anon, authenticated;
grant execute on function public.admin_get_pass_grant(uuid) to authenticated;

create or replace function public.admin_set_pass_grant(p_profile_id uuid, p_days integer)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode alterar o Premium.'; end if;
  if p_days is null or p_days < 0 or p_days > 3650 then
    raise exception 'Informe de 1 a 3650 dias, ou 0 para desativar.';
  end if;
  if not exists(select 1 from public.public_profiles where id = p_profile_id) then
    raise exception 'Jogador não encontrado.';
  end if;
  if p_days = 0 then
    update public.pass_grants set revoked_at = now(), updated_at = now()
      where profile_id = p_profile_id and revoked_at is null;
  else
    insert into public.pass_grants(profile_id, grant_ends_at, revoked_at, granted_by, updated_at)
      values(p_profile_id, now() + make_interval(days => p_days), null, auth.uid(), now())
    on conflict (profile_id) do update set
      grant_ends_at = excluded.grant_ends_at,
      revoked_at = null,
      granted_by = excluded.granted_by,
      updated_at = now();
  end if;
  return public.admin_get_pass_grant(p_profile_id);
end;
$$;
revoke execute on function public.admin_set_pass_grant(uuid,integer) from public, anon, authenticated;
grant execute on function public.admin_set_pass_grant(uuid,integer) to authenticated;

notify pgrst, 'reload schema';
commit;
