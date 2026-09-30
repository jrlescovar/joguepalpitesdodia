begin;

-- The earlier Stripe Pix checkout had not been enabled in this project.
-- Install its prepaid ledger while preserving current cosmetic access rules.
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
revoke all on public.pass_prepaid,public.pass_prepaid_payments from public,anon,authenticated;
grant select,insert,update on public.pass_prepaid to service_role;
grant select,insert on public.pass_prepaid_payments to service_role;
drop trigger if exists credit_pix_boxes on public.pass_prepaid_payments;
create trigger credit_pix_boxes after insert on public.pass_prepaid_payments for each row execute function public.credit_pix_boxes();

create or replace function public.pass_active(p_profile_id uuid)
returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
  select exists(select 1 from public.pass_subscriptions s where s.profile_id=p_profile_id and s.status='active' and s.current_period_ends_at>now())
    or exists(select 1 from public.pass_grants g where g.profile_id=p_profile_id and g.revoked_at is null and g.grant_ends_at>now())
    or exists(select 1 from public.pass_prepaid x where x.profile_id=p_profile_id and x.ends_at>now());
$$;
revoke all on function public.pass_active(uuid) from public,anon,authenticated;

create or replace function public.get_pass_status()
returns jsonb language sql security definer set search_path=public,auth,pg_temp as $$
  select jsonb_build_object(
    'active',public.pass_active(p.id),
    'status',coalesce(s.status,'none'),
    'periodEndsAt',s.current_period_ends_at,
    'cancelAtPeriodEnd',coalesce(s.cancel_at_period_end,false),
    'freeActive',coalesce(g.revoked_at is null and g.grant_ends_at>now(),false),
    'freeEndsAt',case when g.revoked_at is null and g.grant_ends_at>now() then g.grant_ends_at else null end,
    'prepaidActive',coalesce(x.ends_at>now(),false),
    'prepaidEndsAt',case when x.ends_at>now() then x.ends_at else null end,
    'borderStyle',case when public.box_style_allowed(p.id,'frame',p.pass_border_style) then p.pass_border_style else 'none' end,
    'nameStyle',case when public.box_style_allowed(p.id,'name',p.pass_name_style) then p.pass_name_style else 'none' end
  ) from public.public_profiles p
  left join public.pass_subscriptions s on s.profile_id=p.id
  left join public.pass_grants g on g.profile_id=p.id
  left join public.pass_prepaid x on x.profile_id=p.id
  where p.id=public.own_profile_id();
$$;
revoke all on function public.get_pass_status() from public,anon,authenticated;
grant execute on function public.get_pass_status() to authenticated;
notify pgrst,'reload schema';
commit;
