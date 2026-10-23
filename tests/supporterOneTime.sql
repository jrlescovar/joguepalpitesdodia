begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$ declare owner_id uuid; first_order public.infinitepay_orders; second_order public.infinitepay_orders; before_boxes integer; before_fonts integer; saved_end timestamptz; pass jsonb;
begin
 select id into owner_id from public.public_profiles order by player_id desc limit 1;
 -- Simulate an expired entitlement without changing persisted player data.
 delete from public.pass_prepaid where profile_id=owner_id;
 update public.pass_grants set revoked_at=now() where profile_id=owner_id;
 select coalesce((select balance from public.box_balances where profile_id=owner_id),0) into before_boxes;
 select coalesce((select balance from public.font_box_balances where profile_id=owner_id),0) into before_fonts;
 first_order:=public.reserve_infinitepay_order(owner_id,gen_random_uuid(),'jrlescovar','supporter',1,497);
 second_order:=public.reserve_infinitepay_order(owner_id,gen_random_uuid(),'jrlescovar','supporter',1,497);
 if public.pass_active(owner_id) then raise exception 'Pedido não pago liberou acesso.'; end if;
 perform public.settle_infinitepay_order(first_order.id,'test-once-'||first_order.id,'test-once-'||first_order.id,497,'credit_card');
 select ends_at into saved_end from public.pass_prepaid where profile_id=owner_id;
 if saved_end is distinct from now()+interval '30 days' then raise exception 'Compra não concedeu exatamente 30 dias.'; end if;
 perform public.settle_infinitepay_order(first_order.id,'test-once-'||first_order.id,'test-once-'||first_order.id,497,'credit_card');
 if (select ends_at from public.pass_prepaid where profile_id=owner_id) is distinct from saved_end then raise exception 'Repetição duplicou dias.'; end if;
 if (select balance from public.box_balances where profile_id=owner_id)<>before_boxes+7 or (select balance from public.font_box_balances where profile_id=owner_id)<>before_fonts+1 then raise exception 'Benefícios 7+1 incorretos.'; end if;
 perform public.settle_infinitepay_order(second_order.id,'test-once-'||second_order.id,'test-once-'||second_order.id,497,'pix');
 if (select ends_at from public.pass_prepaid where profile_id=owner_id) is distinct from saved_end+interval '30 days' then raise exception 'Segundo pagamento não preservou o prazo existente.'; end if;
 if (select balance from public.box_balances where profile_id=owner_id)<>before_boxes+14 or (select balance from public.font_box_balances where profile_id=owner_id)<>before_fonts+2 then raise exception 'Segunda compra não concedeu 7+1.'; end if;
 update public.pass_prepaid set ends_at=now()-interval '1 second' where profile_id=owner_id;
 if public.pass_active(owner_id) then raise exception 'Apoiador expirado continuou ativo.'; end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and (p.prosrc ilike '%stripe%' or p.prosrc ilike '%pass_subscriptions%')) then raise exception 'Integração antiga ainda utilizada.'; end if;
 raise notice 'OK: 30 dias, expiração, compras manuais, 7+1 caixas e ausência de integração antiga.';
end; $$;
rollback;
