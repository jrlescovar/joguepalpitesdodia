begin;
-- Existing box purchases, supporter payments and tournament orders remain valid.
create table public.coin_wallets (
 profile_id uuid primary key references public.public_profiles(id) on delete cascade,
 balance integer not null default 0 check(balance >= 0),
 updated_at timestamptz not null default now()
);
create table public.coin_box_purchases (
 id uuid primary key default gen_random_uuid(),
 profile_id uuid not null references public.public_profiles(id) on delete cascade,
 request_id uuid not null,
 theme text not null check(theme in ('classic','name','frame','halloween','font')),
 quantity integer not null check(quantity between 1 and 99),
 unit_price integer not null,
 total integer not null check(total=quantity*unit_price),
 created_at timestamptz not null default now(),
 unique(profile_id,request_id),
 check((theme in ('classic','name','frame') and unit_price=100) or (theme='halloween' and unit_price=150) or (theme='font' and unit_price=300))
);
create table public.coin_ledger (
 id uuid primary key default gen_random_uuid(),
 profile_id uuid not null references public.public_profiles(id) on delete cascade,
 delta integer not null check(delta<>0),
 reason text not null check(reason in ('payment','boxes')),
 order_id uuid unique references public.infinitepay_orders(id),
 purchase_id uuid unique references public.coin_box_purchases(id),
 created_at timestamptz not null default now(),
 check((reason='payment' and delta>0 and order_id is not null and purchase_id is null) or (reason='boxes' and delta<0 and purchase_id is not null and order_id is null))
);
alter table public.coin_wallets enable row level security;
alter table public.coin_box_purchases enable row level security;
alter table public.coin_ledger enable row level security;
revoke all on public.coin_wallets,public.coin_box_purchases,public.coin_ledger from public,anon,authenticated;
grant all on public.coin_wallets,public.coin_box_purchases,public.coin_ledger to service_role;
alter table public.infinitepay_orders drop constraint infinitepay_orders_kind_check;
alter table public.infinitepay_orders add constraint infinitepay_orders_kind_check check(kind in ('classic','halloween','font','supporter','tournament','coins'));
alter table public.infinitepay_orders drop constraint infinitepay_orders_check;
alter table public.infinitepay_orders add constraint infinitepay_orders_check check(((((kind = 'classic'::text) AND (((quantity = 3) AND (amount_cents = 321)) OR ((quantity = 7) AND (amount_cents = 567)) OR ((quantity = ANY (ARRAY[11, 12])) AND (amount_cents = 917)))) OR ((kind = 'halloween'::text) AND (((quantity = 2) AND (amount_cents = 321)) OR ((quantity = 6) AND (amount_cents = 567)) OR ((quantity = ANY (ARRAY[10, 12])) AND (amount_cents = 917)))) OR ((kind = 'font'::text) AND (((quantity = 1) AND (amount_cents = 321)) OR ((quantity = 3) AND (amount_cents = 567)) OR ((quantity = ANY (ARRAY[5, 7])) AND (amount_cents = 917)))) OR ((kind = 'supporter'::text) AND (quantity = 1) AND (amount_cents = 497)) OR ((kind = 'tournament'::text) AND (quantity = 1) AND (amount_cents > 0)))) or (kind='coins' and ((quantity=450 and amount_cents=321) or (quantity=1000 and amount_cents=567) or (quantity=2200 and amount_cents=917))));
CREATE OR REPLACE FUNCTION public.settle_infinitepay_order(p_order_id uuid, p_transaction_nsu text, p_invoice_slug text, p_amount_cents integer, p_capture_method text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare purchase public.infinitepay_orders; tournament public.paid_tournaments;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'Acesso negado.'; end if;
 if nullif(p_transaction_nsu,'') is null or nullif(p_invoice_slug,'') is null or p_capture_method is null or p_capture_method not in ('pix','credit_card') then raise exception 'Pagamento inválido.'; end if;
 select * into purchase from public.infinitepay_orders where id=p_order_id for update;
 if not found or p_amount_cents is distinct from purchase.amount_cents then raise exception 'Pagamento inválido.'; end if;
 if purchase.paid_at is not null then
  if purchase.transaction_nsu is distinct from p_transaction_nsu or purchase.invoice_slug is distinct from p_invoice_slug then raise exception 'Pagamento já confirmado com outra transação.'; end if;
  return true;
 end if;
 perform 1 from public.public_profiles where id=purchase.profile_id for update;
 if not found then raise exception 'Perfil não encontrado.'; end if;
 if purchase.kind='tournament' then
  select * into tournament from public.paid_tournaments where id=purchase.tournament_id;
  if not found or purchase.quantity<>1 or (purchase.amount_cents<>tournament.entry_cents and not (
   purchase.id='ebca56e6-475d-4bb6-9e96-e50fc40a6578' and purchase.tournament_id='2e0617ac-f47a-4abd-aae8-68b4c59aa12d'
   and purchase.profile_id='4325ba8c-8b6b-9635-429c-cef8c63ac2d4' and purchase.amount_cents=333)) or purchase.created_at>=tournament.starts_at then raise exception 'Inscrição inválida.'; end if;
 end if;
 update public.infinitepay_orders set transaction_nsu=p_transaction_nsu,invoice_slug=p_invoice_slug,capture_method=p_capture_method,paid_at=now() where id=p_order_id;
 case purchase.kind
  when 'coins' then
   insert into public.coin_wallets(profile_id,balance) values(purchase.profile_id,purchase.quantity)
   on conflict(profile_id) do update set balance=public.coin_wallets.balance+purchase.quantity,updated_at=now();
   insert into public.coin_ledger(profile_id,delta,reason,order_id) values(purchase.profile_id,purchase.quantity,'payment',purchase.id);
  when 'tournament' then
   -- A delayed webhook still honors a verified order made before the start.
   insert into public.paid_tournament_entries(tournament_id,profile_id,order_id)
   values(purchase.tournament_id,purchase.profile_id,purchase.id) on conflict(tournament_id,profile_id) do nothing;
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
   insert into public.pass_prepaid_payments(stripe_session_id,profile_id) values('ip_'||purchase.id::text,purchase.profile_id);
   insert into public.pass_prepaid(profile_id,ends_at) values(purchase.profile_id,now()+interval '30 days')
   on conflict(profile_id) do update set ends_at=greatest(now(),public.pass_prepaid.ends_at)+interval '30 days',updated_at=now();
 end case;
 return true;
end;
$function$
;

create function public.get_coin_wallet() returns jsonb language plpgsql stable security definer set search_path=public,auth,pg_temp as $$
declare owner_id uuid:=public.own_profile_id();
begin
 if owner_id is null then raise exception 'Entre na sua conta.'; end if;
 return jsonb_build_object('balance',coalesce((select balance from public.coin_wallets where profile_id=owner_id),0),
 'unitPrices',jsonb_build_object('classic',100,'name',100,'frame',100,'halloween',150,'font',300));
end; $$;
revoke all on function public.get_coin_wallet() from public,anon;
grant execute on function public.get_coin_wallet() to authenticated;

create function public.buy_boxes_with_coins(p_theme text,p_quantity integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare owner_id uuid:=public.own_profile_id(); cost integer; wallet integer; remaining_boxes integer;
 saved public.coin_box_purchases; target_table text;
begin
 if owner_id is null then raise exception 'Entre na sua conta.'; end if;
 if p_request_id is null or p_quantity is null or p_quantity<1 or p_quantity>99 or p_theme is null or p_theme not in ('classic','name','frame','halloween','font') then raise exception 'Compra inválida.'; end if;
 cost:=case p_theme when 'halloween' then 150 when 'font' then 300 else 100 end;
 target_table:=case p_theme when 'classic' then 'box_balances' when 'name' then 'name_box_balances' when 'frame' then 'frame_box_balances' when 'halloween' then 'halloween_box_balances' when 'font' then 'font_box_balances' end;
 -- Every credit/spend locks this same player before touching the wallet.
 perform 1 from public.public_profiles where id=owner_id for update;
 select * into saved from public.coin_box_purchases where profile_id=owner_id and request_id=p_request_id;
 if found then
  if (saved.theme,saved.quantity) is distinct from (p_theme,p_quantity) then raise exception 'Pedido inválido.'; end if;
 else
  insert into public.coin_wallets(profile_id) values(owner_id) on conflict do nothing;
  select balance into wallet from public.coin_wallets where profile_id=owner_id for update;
  if wallet<cost*p_quantity then raise exception 'Saldo de moedas insuficiente.'; end if;
  insert into public.coin_box_purchases(profile_id,request_id,theme,quantity,unit_price,total)
   values(owner_id,p_request_id,p_theme,p_quantity,cost,cost*p_quantity) returning * into saved;
  update public.coin_wallets set balance=balance-cost*p_quantity,updated_at=now() where profile_id=owner_id;
  insert into public.coin_ledger(profile_id,delta,reason,purchase_id) values(owner_id,-cost*p_quantity,'boxes',saved.id);
  execute format('insert into public.%I(profile_id,balance) values($1,$2) on conflict(profile_id) do update set balance=public.%I.balance+$2',target_table,target_table) using owner_id,p_quantity;
 end if;
 execute format('select balance from public.%I where profile_id=$1',target_table) into remaining_boxes using owner_id;
 return jsonb_build_object('purchaseId',saved.id,'theme',p_theme,'quantity',p_quantity,'balance',(select balance from public.coin_wallets where profile_id=owner_id),'boxBalance',remaining_boxes);
end; $$;
revoke all on function public.buy_boxes_with_coins(text,integer,uuid) from public,anon;
grant execute on function public.buy_boxes_with_coins(text,integer,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
