begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$
declare
  player uuid;
  pack record;
  purchase public.infinitepay_orders;
  before_classic integer;
  before_halloween integer;
begin
  select id into strict player from public.public_profiles order by player_id desc limit 1;
  select coalesce((select balance from public.box_balances where profile_id=player),0) into before_classic;
  select coalesce((select balance from public.halloween_box_balances where profile_id=player),0) into before_halloween;
  for pack in select * from (values ('classic',3,321),('classic',7,567),('classic',11,917),('halloween',2,321),('halloween',6,567),('halloween',10,917),('font',1,321),('font',3,567),('supporter',1,497)) as allowed(kind,quantity,amount)
  loop
    insert into public.infinitepay_orders(profile_id,request_id,handle,kind,quantity,amount_cents)
      values(player,gen_random_uuid(),'jrlescovar',pack.kind,pack.quantity,pack.amount) returning * into purchase;
    if pack.amount=917 then
      perform public.settle_infinitepay_order(purchase.id,'test-large-'||purchase.id,'test-large-'||purchase.id,917,'pix');
      perform public.settle_infinitepay_order(purchase.id,'test-large-'||purchase.id,'test-large-'||purchase.id,917,'pix');
    end if;
    begin
      insert into public.infinitepay_orders(profile_id,request_id,handle,kind,quantity,amount_cents)
        values(player,gen_random_uuid(),'jrlescovar',pack.kind,pack.quantity,1);
      raise exception 'Preço adulterado aceito para %/%',pack.kind,pack.quantity;
    exception when check_violation then null;
    end;
  end loop;
  if (select balance from public.box_balances where profile_id=player) <> before_classic+11 then
    raise exception 'Entrega incorreta ou duplicada das 11 caixas.';
  end if;
  if (select balance from public.halloween_box_balances where profile_id=player) <> before_halloween+10 then
    raise exception 'Entrega incorreta ou duplicada das 10 caixas de Halloween.';
  end if;
  for pack in select * from (values ('classic',10),('halloween',11),('font',11)) as invalid(kind,quantity)
  loop
    begin
      insert into public.infinitepay_orders(profile_id,request_id,handle,kind,quantity,amount_cents)
        values(player,gen_random_uuid(),'jrlescovar',pack.kind,pack.quantity,917);
      raise exception 'Pacote inválido aceito para %/%',pack.kind,pack.quantity;
    exception when check_violation then null;
    end;
  end loop;
end;
$$;
rollback;
select true as large_pack_tests_passed;
