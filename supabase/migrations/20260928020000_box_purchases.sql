begin;

create table public.box_purchases (
  stripe_session_id text primary key check (stripe_session_id like 'cs_%'),
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  quantity integer not null,
  amount_cents integer not null,
  paid_at timestamptz not null default now(),
  check ((quantity = 3 and amount_cents = 321) or (quantity = 7 and amount_cents = 567))
);
alter table public.box_purchases enable row level security;
revoke all on public.box_purchases from public, anon, authenticated;

create or replace function public.credit_box_purchase(p_profile_id uuid, p_session_id text, p_quantity integer, p_amount_cents integer)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_profile_id is null or p_session_id is null or p_session_id not like 'cs_%'
     or p_quantity is null or p_amount_cents is null
     or not ((p_quantity = 3 and p_amount_cents = 321) or (p_quantity = 7 and p_amount_cents = 567)) then
    raise exception 'Compra de caixas inválida.';
  end if;
  insert into public.box_purchases(stripe_session_id,profile_id,quantity,amount_cents)
    values(p_session_id,p_profile_id,p_quantity,p_amount_cents) on conflict do nothing;
  if found then
    insert into public.box_balances(profile_id,balance) values(p_profile_id,p_quantity)
      on conflict(profile_id) do update set balance=public.box_balances.balance+p_quantity;
  end if;
end;
$$;
revoke execute on function public.credit_box_purchase(uuid,text,integer,integer) from public, anon, authenticated;
grant execute on function public.credit_box_purchase(uuid,text,integer,integer) to service_role;
commit;
