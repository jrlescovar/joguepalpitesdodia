begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$declare target uuid:=gen_random_uuid(); item record; purchase public.infinitepay_orders; retry public.infinitepay_orders;
 balance_table text; before_balance integer; after_balance integer; failed boolean;
begin
 insert into public.public_profiles(id,player_id,username,avatar_color) values(target,9900401,'packqa1','#3b82f6');
 for item in select * from(values('classic',12),('halloween',12),('font',7),('classic',11),('halloween',10),('font',5)) packs(kind,quantity) loop
  balance_table:=case item.kind when 'classic' then 'box_balances' when 'halloween' then 'halloween_box_balances' else 'font_box_balances' end;
  execute format('select coalesce((select balance from public.%I where profile_id=$1),0)',balance_table) into before_balance using target;
  purchase:=public.reserve_infinitepay_order(target,gen_random_uuid(),'jrlescovar',item.kind,item.quantity,917);
  retry:=public.reserve_infinitepay_order(target,purchase.request_id,'jrlescovar',item.kind,item.quantity,917);
  if retry.id<>purchase.id or purchase.amount_cents<>917 or purchase.quantity<>item.quantity then raise exception 'Incorrect reservation/retry';end if;
  failed:=false;begin perform public.settle_infinitepay_order(purchase.id,'packqa-'||purchase.id,'packqa-'||purchase.id,1,'pix');exception when others then if sqlerrm='Pagamento inválido.' then failed:=true;else raise;end if;end;
  if not failed then raise exception 'Invalid paid amount accepted';end if;
  perform public.settle_infinitepay_order(purchase.id,'packqa-'||purchase.id,'packqa-'||purchase.id,917,'pix');
  perform public.settle_infinitepay_order(purchase.id,'packqa-'||purchase.id,'packqa-'||purchase.id,917,'pix');
  execute format('select balance from public.%I where profile_id=$1',balance_table) into after_balance using target;
  if after_balance<>before_balance+item.quantity then raise exception 'Incorrect delivery/retry for %/%',item.kind,item.quantity;end if;
 end loop;
 failed:=false;begin perform public.reserve_infinitepay_order(target,gen_random_uuid(),'jrlescovar','font',7,321);exception when check_violation then failed:=true;end;
 if not failed then raise exception 'Wrong quantity/price pair accepted';end if;
 if has_function_privilege('authenticated','public.settle_infinitepay_order(uuid,text,text,integer,text)','execute') then raise exception 'Player can settle payments';end if;
end $$;
select jsonb_build_object('passed',true,'checks','new quantities, historical quantities, correct prices, exact delivery, duplicate reservation/settlement, bad payment denial, service-only settlement') pack_test;
rollback;
