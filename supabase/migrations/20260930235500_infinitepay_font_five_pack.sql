begin;

alter table public.infinitepay_orders drop constraint infinitepay_orders_check;
alter table public.infinitepay_orders add constraint infinitepay_orders_check check (
  (kind='classic' and ((quantity=3 and amount_cents=321) or (quantity=7 and amount_cents=567) or (quantity=11 and amount_cents=917)))
  or (kind='halloween' and ((quantity=2 and amount_cents=321) or (quantity=6 and amount_cents=567) or (quantity=10 and amount_cents=917)))
  or (kind='font' and ((quantity=1 and amount_cents=321) or (quantity=3 and amount_cents=567) or (quantity=5 and amount_cents=917)))
  or (kind='supporter' and quantity=1 and amount_cents=497)
);

commit;
