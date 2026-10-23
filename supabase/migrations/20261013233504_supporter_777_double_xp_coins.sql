begin;
do $$declare constraint_definition text;begin
 select pg_get_constraintdef(oid) into constraint_definition from pg_constraint where conrelid='public.infinitepay_orders'::regclass and conname='infinitepay_orders_check';
 if position('(amount_cents = 497)' in constraint_definition)=0 then raise exception 'Unexpected supporter price constraint';end if;
 alter table public.infinitepay_orders drop constraint infinitepay_orders_check;
 execute 'alter table public.infinitepay_orders add constraint infinitepay_orders_check '||replace(constraint_definition,'(amount_cents = 497)','(amount_cents in (497,777))');
end $$;
create or replace function public.pass_xp(p_base integer,p_profile_id uuid) returns integer language sql stable security definer set search_path=public,auth,pg_temp as $$
 select case when public.pass_active(p_profile_id) then p_base*2 else p_base end;
$$;
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
   -- Credit the new bundle only after a verified R$7.77 payment. Old orders stay valid.
   if purchase.amount_cents=777 then
    insert into public.coin_wallets(profile_id,balance) values(purchase.profile_id,1000)
    on conflict(profile_id) do update set balance=public.coin_wallets.balance+1000,updated_at=now();
    insert into public.coin_ledger(profile_id,delta,reason,order_id) values(purchase.profile_id,1000,'payment',purchase.id);
   end if;
   insert into public.pass_prepaid_payments(stripe_session_id,profile_id) values('ip_'||purchase.id::text,purchase.profile_id);
   insert into public.pass_prepaid(profile_id,ends_at) values(purchase.profile_id,now()+interval '30 days')
   on conflict(profile_id) do update set ends_at=greatest(now(),public.pass_prepaid.ends_at)+interval '30 days',updated_at=now();
 end case;
 return true;
end;
$function$;
commit;
