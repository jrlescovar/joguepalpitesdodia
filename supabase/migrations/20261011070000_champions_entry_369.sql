begin;
do $$
declare tournament public.paid_tournaments; definition text; anchor text;
begin
 select * into tournament from public.paid_tournaments where id='2e0617ac-f47a-4abd-aae8-68b4c59aa12d' for update;
 if not found or not tournament.enabled or tournament.metric<>'classic' or tournament.entry_cents not in (333,369) or tournament.starts_at<=clock_timestamp() then
  raise exception 'Torneio ou período de inscrição inesperado.';
 end if;
 -- The only existing checkout belongs to the already enrolled zaotips.
 -- Retain its original amount; all new unenrolled buyers reserve the new fee.
 if exists(select 1 from public.infinitepay_orders o where o.tournament_id=tournament.id and o.amount_cents<>369 and not (
  o.id='ebca56e6-475d-4bb6-9e96-e50fc40a6578' and o.profile_id='4325ba8c-8b6b-9635-429c-cef8c63ac2d4' and o.amount_cents=333
  and exists(select 1 from public.paid_tournament_entries e where e.tournament_id=o.tournament_id and e.profile_id=o.profile_id)
 )) then raise exception 'Há outro pedido antigo; conferir antes de alterar o preço.';end if;
 definition:=pg_get_functiondef('public.settle_infinitepay_order(uuid,text,text,integer,text)'::regprocedure);
 anchor:='purchase.amount_cents<>tournament.entry_cents';
 if position('ebca56e6-475d-4bb6-9e96-e50fc40a6578' in definition)=0 then
  if position(anchor in definition)=0 then raise exception 'Apuração de pagamento inesperada.';end if;
  definition:=replace(definition,anchor,$guard$(purchase.amount_cents<>tournament.entry_cents and not (
   purchase.id='ebca56e6-475d-4bb6-9e96-e50fc40a6578' and purchase.tournament_id='2e0617ac-f47a-4abd-aae8-68b4c59aa12d'
   and purchase.profile_id='4325ba8c-8b6b-9635-429c-cef8c63ac2d4' and purchase.amount_cents=333))$guard$);
  execute definition;
 end if;
 update public.paid_tournaments set entry_cents=369 where id=tournament.id;
end $$;
commit;
