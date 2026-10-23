begin;
-- Accept the larger offers while retaining valid historical/pending orders.
-- No existing purchase quantities or player balances are changed.
alter table public.infinitepay_orders drop constraint infinitepay_orders_check;
alter table public.infinitepay_orders add constraint infinitepay_orders_check check (
 (kind='classic' and ((quantity=3 and amount_cents=321) or (quantity=7 and amount_cents=567) or (quantity in (11,12) and amount_cents=917)))
 or (kind='halloween' and ((quantity=2 and amount_cents=321) or (quantity=6 and amount_cents=567) or (quantity in (10,12) and amount_cents=917)))
 or (kind='font' and ((quantity=1 and amount_cents=321) or (quantity=3 and amount_cents=567) or (quantity in (5,7) and amount_cents=917)))
 or (kind='supporter' and quantity=1 and amount_cents=497)
 or (kind='tournament' and quantity=1 and amount_cents>0)
);
notify pgrst,'reload schema';
commit;
