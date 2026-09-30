begin;

create table public.infinitepay_orders (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  request_id uuid not null,
  handle text not null,
  kind text not null check (kind in ('classic','halloween','font','supporter')),
  quantity integer not null,
  amount_cents integer not null,
  checkout_url text,
  transaction_nsu text unique,
  invoice_slug text unique,
  capture_method text check (capture_method in ('pix','credit_card')),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  unique (profile_id, request_id),
  check (
    (kind='classic' and ((quantity=3 and amount_cents=321) or (quantity=7 and amount_cents=567)))
    or (kind='halloween' and ((quantity=2 and amount_cents=321) or (quantity=6 and amount_cents=567)))
    or (kind='font' and ((quantity=1 and amount_cents=321) or (quantity=3 and amount_cents=567)))
    or (kind='supporter' and quantity=1 and amount_cents=497)
  )
);
alter table public.infinitepay_orders enable row level security;
revoke all on public.infinitepay_orders from public, anon, authenticated;
grant select, insert, update on public.infinitepay_orders to service_role;

create function public.reserve_infinitepay_order(p_profile_id uuid, p_request_id uuid, p_handle text, p_kind text, p_quantity integer, p_amount_cents integer)
returns public.infinitepay_orders language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare saved public.infinitepay_orders;
begin
  if auth.role() is distinct from 'service_role' then raise exception 'Acesso negado.'; end if;
  if p_handle is null or p_handle !~ '^[a-zA-Z0-9_-]{1,80}$' then raise exception 'Conta de pagamento inválida.'; end if;
  perform 1 from public.public_profiles where id=p_profile_id for update;
  if not found then raise exception 'Perfil não encontrado.'; end if;
  select * into saved from public.infinitepay_orders where profile_id=p_profile_id and request_id=p_request_id;
  if found then
    if (saved.kind,saved.quantity,saved.amount_cents,saved.handle) is distinct from (p_kind,p_quantity,p_amount_cents,p_handle) then
      raise exception 'Pedido inválido.';
    end if;
    return saved;
  end if;
  if (select count(*) from public.infinitepay_orders where profile_id=p_profile_id and created_at>now()-interval '1 hour') >= 20 then
    raise exception 'Muitas tentativas de pagamento. Aguarde um pouco.';
  end if;
  if p_kind='supporter' and (
    exists(select 1 from public.pass_subscriptions where profile_id=p_profile_id and status='active' and current_period_ends_at>now())
    or exists(select 1 from public.pass_prepaid where profile_id=p_profile_id and ends_at>now())
  ) then raise exception 'Seu Apoiador pago ainda está ativo.'; end if;
  insert into public.infinitepay_orders(profile_id,request_id,handle,kind,quantity,amount_cents)
    values(p_profile_id,p_request_id,p_handle,p_kind,p_quantity,p_amount_cents) returning * into saved;
  return saved;
end;
$$;
revoke all on function public.reserve_infinitepay_order(uuid,uuid,text,text,integer,integer) from public,anon,authenticated;
grant execute on function public.reserve_infinitepay_order(uuid,uuid,text,text,integer,integer) to service_role;

-- Only the server calls this after payment_check has verified this exact order.
-- The row lock and unique transaction ID prevent webhook/return races and replay.
create function public.settle_infinitepay_order(p_order_id uuid,p_transaction_nsu text,p_invoice_slug text,p_amount_cents integer,p_capture_method text)
returns boolean language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare purchase public.infinitepay_orders;
begin
  if auth.role() is distinct from 'service_role' then raise exception 'Acesso negado.'; end if;
  if nullif(p_transaction_nsu,'') is null or nullif(p_invoice_slug,'') is null or p_capture_method is null or p_capture_method not in ('pix','credit_card') then
    raise exception 'Pagamento inválido.';
  end if;
  select * into purchase from public.infinitepay_orders where id=p_order_id for update;
  if not found or p_amount_cents is distinct from purchase.amount_cents then raise exception 'Pagamento inválido.'; end if;
  if purchase.paid_at is not null then
    if purchase.transaction_nsu is distinct from p_transaction_nsu or purchase.invoice_slug is distinct from p_invoice_slug then
      raise exception 'Pagamento já confirmado com outra transação.';
    end if;
    return true;
  end if;
  perform 1 from public.public_profiles where id=purchase.profile_id for update;
  if not found then raise exception 'Perfil não encontrado.'; end if;
  update public.infinitepay_orders set transaction_nsu=p_transaction_nsu,invoice_slug=p_invoice_slug,
    capture_method=p_capture_method,paid_at=now() where id=p_order_id;
  case purchase.kind
    when 'classic' then
      insert into public.box_balances(profile_id,balance) values(purchase.profile_id,purchase.quantity)
        on conflict(profile_id) do update set balance=public.box_balances.balance+purchase.quantity;
    when 'font' then
      insert into public.font_box_balances(profile_id,balance) values(purchase.profile_id,purchase.quantity)
        on conflict(profile_id) do update set balance=public.font_box_balances.balance+purchase.quantity;
    when 'halloween' then
      insert into public.halloween_box_balances(profile_id,balance) values(purchase.profile_id,purchase.quantity)
        on conflict(profile_id) do update set balance=public.halloween_box_balances.balance+purchase.quantity;
    when 'supporter' then
      -- This existing paid-period ledger also grants the 7+1 boxes and medal month.
      insert into public.pass_prepaid_payments(stripe_session_id,profile_id)
        values('ip_'||purchase.id::text,purchase.profile_id);
      insert into public.pass_prepaid(profile_id,ends_at) values(purchase.profile_id,now()+interval '30 days')
        on conflict(profile_id) do update set ends_at=greatest(now(),public.pass_prepaid.ends_at)+interval '30 days',updated_at=now();
  end case;
  return true;
end;
$$;
revoke all on function public.settle_infinitepay_order(uuid,text,text,integer,text) from public,anon,authenticated;
grant execute on function public.settle_infinitepay_order(uuid,text,text,integer,text) to service_role;
notify pgrst,'reload schema';
commit;
