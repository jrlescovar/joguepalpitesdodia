begin;

-- One grant per subscription period, prepaid payment, or free admin grant.
create table if not exists public.pass_box_rewards (
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  source text not null check (source in ('subscription','pix','free')),
  period_key text not null,
  quantity integer not null default 5 check (quantity = 5),
  granted_at timestamptz not null default now(),
  primary key (profile_id, source, period_key)
);
alter table public.pass_box_rewards enable row level security;
revoke all on public.pass_box_rewards from public, anon, authenticated;

create or replace function public.credit_pass_boxes(p_profile_id uuid, p_source text, p_period_key text)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  if p_profile_id is null or p_source not in ('subscription','pix','free') or nullif(p_period_key,'') is null then
    raise exception 'Concessão de caixas inválida.';
  end if;
  insert into public.pass_box_rewards(profile_id,source,period_key)
    values(p_profile_id,p_source,p_period_key) on conflict do nothing;
  if found then
    insert into public.box_balances(profile_id,balance) values(p_profile_id,5)
      on conflict(profile_id) do update set balance=public.box_balances.balance+5;
  end if;
end;
$$;
revoke execute on function public.credit_pass_boxes(uuid,text,text) from public, anon, authenticated;

create or replace function public.credit_subscription_boxes()
returns trigger language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  if new.status='active' and new.current_period_ends_at > now() and new.stripe_subscription_id is not null then
    perform public.credit_pass_boxes(new.profile_id,'subscription',new.stripe_subscription_id || ':' || new.current_period_ends_at::date::text);
  end if;
  return new;
end;
$$;
drop trigger if exists credit_subscription_boxes on public.pass_subscriptions;
create trigger credit_subscription_boxes after insert or update on public.pass_subscriptions
  for each row execute function public.credit_subscription_boxes();

create or replace function public.credit_pix_boxes()
returns trigger language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  perform public.credit_pass_boxes(new.profile_id,'pix',new.stripe_session_id);
  return new;
end;
$$;
do $$
begin
  if to_regclass('public.pass_prepaid_payments') is not null then
    execute 'drop trigger if exists credit_pix_boxes on public.pass_prepaid_payments';
    execute 'create trigger credit_pix_boxes after insert on public.pass_prepaid_payments for each row execute function public.credit_pix_boxes()';
  end if;
end;
$$;

create or replace function public.credit_free_pass_boxes()
returns trigger language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  if new.revoked_at is null and new.grant_ends_at > now() then
    perform public.credit_pass_boxes(new.profile_id,'free',new.grant_ends_at::text);
  end if;
  return new;
end;
$$;
drop trigger if exists credit_free_pass_boxes on public.pass_grants;
create trigger credit_free_pass_boxes after insert or update on public.pass_grants
  for each row execute function public.credit_free_pass_boxes();

-- Current active supporters receive the newly introduced benefit once.
select public.credit_pass_boxes(s.profile_id,'subscription',s.stripe_subscription_id || ':' || s.current_period_ends_at::date::text)
from public.pass_subscriptions s
where s.status='active' and s.current_period_ends_at>now() and s.stripe_subscription_id is not null;
do $$
begin
  if to_regclass('public.pass_prepaid_payments') is not null and to_regclass('public.pass_prepaid') is not null then
    execute 'select public.credit_pass_boxes(x.profile_id,''pix'',x.stripe_session_id) from public.pass_prepaid_payments x join public.pass_prepaid p on p.profile_id=x.profile_id where p.ends_at>now()';
  end if;
end;
$$;
select public.credit_pass_boxes(g.profile_id,'free',g.grant_ends_at::text)
from public.pass_grants g where g.revoked_at is null and g.grant_ends_at>now();

notify pgrst, 'reload schema';
commit;
