-- Run after the coin migration, inside this rollback-only transaction.
-- No payment processor is called and no player data survives this test.
begin;
do $$
declare player uuid; auth_id uuid; pack record; saved public.infinitepay_orders;
 result jsonb; repeated jsonb; request_id uuid; theme text; target_table text;
 box_before integer; box_after integer; ledger_before integer;
begin
 select profile_id,auth_user_id into player,auth_id from public.private_profiles where auth_user_id is not null limit 1;
 assert player is not null, 'A linked profile is needed for this rollback test';
 assert not exists(select 1 from public.coin_wallets where profile_id=player), 'Run with a new wallet before launch';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',auth_id,'role','authenticated')::text,true);
 assert public.get_coin_wallet()->>'balance'='0', 'New wallet must show zero';
 assert public.get_coin_wallet()->'unitPrices'=jsonb_build_object('classic',100,'name',100,'frame',100,'halloween',150,'font',300), 'Unit prices';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',auth_id,'role','service_role')::text,true);
 for pack in select * from (values(450,321),(1000,567),(2200,917)) as p(quantity,cents) loop
  request_id:=gen_random_uuid();
  saved:=public.reserve_infinitepay_order(player,request_id,'coin-test','coins',pack.quantity,pack.cents);
  assert saved.id=(public.reserve_infinitepay_order(player,request_id,'coin-test','coins',pack.quantity,pack.cents)).id, 'Payment reservation is idempotent';
  assert not exists(select 1 from public.coin_ledger where order_id=saved.id), 'Unpaid order must not grant coins';
  begin
   perform public.settle_infinitepay_order(saved.id,'test-'||saved.id,'test-'||saved.id,pack.cents+1,'pix');
   assert false,'Wrong amount was accepted';
  exception when raise_exception then assert sqlerrm='Pagamento inválido.', 'Wrong amount rejected'; end;
  perform public.settle_infinitepay_order(saved.id,'test-'||saved.id,'test-'||saved.id,pack.cents,'pix');
  perform public.settle_infinitepay_order(saved.id,'test-'||saved.id,'test-'||saved.id,pack.cents,'pix');
 end loop;
 assert (select balance from public.coin_wallets where profile_id=player)=3650, 'Three paid packs; replay adds nothing';
 assert (select count(*) from public.coin_ledger where profile_id=player)=3, 'Three credit records only';
 begin
  perform public.reserve_infinitepay_order(player,gen_random_uuid(),'coin-test','coins',450,1);
  assert false,'Incorrect pack price accepted';
 exception when check_violation then null; end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',auth_id,'role','authenticated')::text,true);
 for theme in select unnest(array['classic','name','frame','halloween','font']) loop
  target_table:=case theme when 'classic' then 'box_balances' when 'name' then 'name_box_balances' when 'frame' then 'frame_box_balances' when 'halloween' then 'halloween_box_balances' else 'font_box_balances' end;
  execute format('select coalesce((select balance from public.%I where profile_id=$1),0)',target_table) into box_before using player;
  request_id:=gen_random_uuid();
  result:=public.buy_boxes_with_coins(theme,1,request_id);
  repeated:=public.buy_boxes_with_coins(theme,1,request_id);
  assert result=repeated,'Same purchase must return without a second debit';
  execute format('select balance from public.%I where profile_id=$1',target_table) into box_after using player;
  assert box_after=box_before+1,'Correct inventory receives one box';
  begin
   perform public.buy_boxes_with_coins(theme,2,request_id);
   assert false,'Request ID collision accepted';
  exception when raise_exception then assert sqlerrm='Pedido inválido.', 'Collision rejected'; end;
 end loop;
 assert (select balance from public.coin_wallets where profile_id=player)=2900, 'All five unit prices deducted correctly';
 result:=public.buy_boxes_with_coins('classic',2,gen_random_uuid());
 assert result->>'quantity'='2' and result->>'balance'='2700','Batch quantity multiplies the price';
 ledger_before:=(select count(*) from public.coin_ledger where profile_id=player);
 begin
  perform public.buy_boxes_with_coins('font',99,gen_random_uuid());
  assert false,'Insufficient balance accepted';
 exception when raise_exception then assert sqlerrm='Saldo de moedas insuficiente.', 'Insufficient balance rejected'; end;
 begin
  perform public.buy_boxes_with_coins('classic',0,gen_random_uuid());
  assert false,'Zero quantity accepted';
 exception when raise_exception then assert sqlerrm='Compra inválida.', 'Zero rejected'; end;
 begin
  perform public.buy_boxes_with_coins('classic',-1,gen_random_uuid());
  assert false,'Negative quantity accepted';
 exception when raise_exception then assert sqlerrm='Compra inválida.', 'Negative rejected'; end;
 begin
  perform public.buy_boxes_with_coins('classic',100,gen_random_uuid());
  assert false,'Oversized quantity accepted';
 exception when raise_exception then assert sqlerrm='Compra inválida.', 'Oversized rejected'; end;
 begin
  perform public.buy_boxes_with_coins('invalid',1,gen_random_uuid());
  assert false,'Unknown box accepted';
 exception when raise_exception then assert sqlerrm='Compra inválida.', 'Unknown theme rejected'; end;
 begin
  perform public.buy_boxes_with_coins('classic',1,null);
  assert false,'Missing request ID accepted';
 exception when raise_exception then assert sqlerrm='Compra inválida.', 'Missing ID rejected'; end;
 begin
  perform public.settle_infinitepay_order(saved.id,'test-'||saved.id,'test-'||saved.id,pack.cents,'pix');
  assert false,'Player can settle payments';
 exception when raise_exception then assert sqlerrm='Acesso negado.', 'Only server confirms payments'; end;
 assert (select count(*) from public.coin_ledger where profile_id=player)=ledger_before,'Failed operations have no ledger effect';
 assert (select balance from public.coin_wallets where profile_id=player)=(select sum(delta) from public.coin_ledger where profile_id=player),'Wallet equals ledger';
 perform set_config('request.jwt.claims','{}',true);
 begin
  perform public.get_coin_wallet();
  assert false,'Anonymous wallet accepted';
 exception when raise_exception then assert sqlerrm='Entre na sua conta.', 'Authentication required'; end;
 begin
  perform public.buy_boxes_with_coins('classic',1,gen_random_uuid());
  assert false,'Anonymous purchase accepted';
 exception when raise_exception then assert sqlerrm='Entre na sua conta.', 'Authentication required for spending'; end;
 assert not has_table_privilege('authenticated','public.coin_wallets','UPDATE'),'Players cannot write balances directly';
 assert not has_table_privilege('authenticated','public.coin_ledger','INSERT'),'Players cannot forge credits';
 assert not has_function_privilege('anon','public.buy_boxes_with_coins(text,integer,uuid)','EXECUTE'),'Anonymous RPC denied';
 assert has_function_privilege('authenticated','public.buy_boxes_with_coins(text,integer,uuid)','EXECUTE'),'Signed-in purchase allowed';
end $$;
select jsonb_build_object('passed',true,'scope','all coin packs, unpaid orders, replays, five box inventories, batch quantity, invalid inputs, insufficient balance, ledger and permissions') as coin_tests;
rollback;
