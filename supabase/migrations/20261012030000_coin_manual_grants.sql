begin;
-- Server-only grants are recorded separately from verified paid orders.
alter table public.coin_ledger add column grant_key text unique;
alter table public.coin_ledger drop constraint coin_ledger_reason_check;
alter table public.coin_ledger add constraint coin_ledger_reason_check check(reason in ('payment','boxes','manual_grant'));
alter table public.coin_ledger drop constraint coin_ledger_check;
alter table public.coin_ledger add constraint coin_ledger_check check(
 (reason='payment' and delta>0 and order_id is not null and purchase_id is null and grant_key is null)
 or (reason='boxes' and delta<0 and purchase_id is not null and order_id is null and grant_key is null)
 or (reason='manual_grant' and delta>0 and order_id is null and purchase_id is null and nullif(btrim(grant_key),'') is not null)
);
commit;
