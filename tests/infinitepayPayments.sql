begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$
declare
  profile uuid;
  first_order public.infinitepay_orders;
  second_order public.infinitepay_orders;
  before_classic integer;
  before_font integer;
  before_rewards integer;
  before_end timestamptz;
  after_end timestamptz;
begin
  select id into profile from public.public_profiles order by player_id desc limit 1;
  select coalesce((select balance from public.box_balances where profile_id=profile),0) into before_classic;
  select coalesce((select balance from public.font_box_balances where profile_id=profile),0) into before_font;
  select count(*) into before_rewards from public.pass_box_rewards where profile_id=profile and source='pix';
  first_order:=public.reserve_infinitepay_order(profile,gen_random_uuid(),'jrlescovar','font',1,321);
  perform public.settle_infinitepay_order(first_order.id,'test-ip-font-'||first_order.id,'test-ip-font-'||first_order.id,321,'pix');
  perform public.settle_infinitepay_order(first_order.id,'test-ip-font-'||first_order.id,'test-ip-font-'||first_order.id,321,'pix');
  if (select balance from public.font_box_balances where profile_id=profile) <> before_font+1 then raise exception 'Entrega duplicada de fonte.'; end if;
  insert into public.infinitepay_orders(profile_id,request_id,handle,kind,quantity,amount_cents)
    values(profile,gen_random_uuid(),'jrlescovar','supporter',1,497) returning * into second_order;
  select ends_at into before_end from public.pass_prepaid where profile_id=profile;
  perform public.settle_infinitepay_order(second_order.id,'test-ip-pass-'||second_order.id,'test-ip-pass-'||second_order.id,497,'pix');
  select ends_at into after_end from public.pass_prepaid where profile_id=profile;
  if not public.pass_active(profile) then raise exception 'Apoiador não foi ativado.'; end if;
  if after_end is distinct from greatest(now(),before_end)+interval '30 days' then raise exception 'Período incorreto.'; end if;
  perform public.settle_infinitepay_order(second_order.id,'test-ip-pass-'||second_order.id,'test-ip-pass-'||second_order.id,497,'pix');
  if (select ends_at from public.pass_prepaid where profile_id=profile) is distinct from after_end then raise exception 'Período duplicado.'; end if;
  if (select balance from public.box_balances where profile_id=profile) <> before_classic+7 then raise exception 'Caixas de apoiador incorretas.'; end if;
  if (select balance from public.font_box_balances where profile_id=profile) <> before_font+2 then raise exception 'Caixa de fonte de apoiador incorreta.'; end if;
  if (select count(*) from public.pass_box_rewards where profile_id=profile and source='pix') <> before_rewards+1 then raise exception 'Mês de medalha duplicado.'; end if;
  begin
    perform public.settle_infinitepay_order(second_order.id,'another-txn','another-invoice',497,'pix');
    raise exception 'Transação diferente foi aceita.';
  exception when raise_exception then
    if sqlerrm='Transação diferente foi aceita.' then raise; end if;
  end;
  begin
    perform public.settle_infinitepay_order(first_order.id,'test-ip-font-'||first_order.id,'test-ip-font-'||first_order.id,1,'pix');
    raise exception 'Preço incorreto foi aceito.';
  exception when raise_exception then
    if sqlerrm='Preço incorreto foi aceito.' then raise; end if;
  end;
  insert into public.infinitepay_orders(profile_id,request_id,handle,kind,quantity,amount_cents)
    values(profile,gen_random_uuid(),'jrlescovar','font',1,321) returning * into second_order;
  begin
    perform public.settle_infinitepay_order(second_order.id,'test-ip-font-'||first_order.id,'test-ip-font-'||first_order.id,321,'pix');
    raise exception 'A mesma transação foi usada em dois pedidos.';
  exception when unique_violation then null;
  end;
  if (select paid_at from public.infinitepay_orders where id=second_order.id) is not null then raise exception 'Pedido duplicado foi marcado como pago.'; end if;
  perform set_config('request.jwt.claims','{"role":"authenticated"}',true);
  begin
    perform public.settle_infinitepay_order(second_order.id,'forged','forged',321,'pix');
    raise exception 'Jogador conseguiu liberar compra.';
  exception when raise_exception then
    if sqlerrm='Jogador conseguiu liberar compra.' then raise; end if;
  end;
  raise notice 'OK: compra, duplicidade, valor, 30 dias, 7+1 caixas e mês de medalha.';
end;
$$;
rollback;
