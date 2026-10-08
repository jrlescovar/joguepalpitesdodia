-- Run after the migration, inside a transaction that is rolled back.
do $$
declare viewer uuid; account uuid; target uuid := '36b34446-4dcf-4d63-8cf3-5ba8ec8d1113';
 first_order public.infinitepay_orders; second_order public.infinitepay_orders;
 page jsonb; blocked boolean; participant record; test_order uuid; n integer := 0; initial_boxes integer;
begin
 select v.profile_id,v.auth_user_id into viewer,account from public.private_profiles v
 join public.public_profiles p on p.id=v.profile_id where v.auth_user_id is not null
 order by (p.username='jrlescovar') desc,p.player_id limit 1;
 if viewer is null then raise exception 'An existing signed-in profile is required'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',account,'role','authenticated')::text,true);
 page := public.get_finishing_tournament(target);
 if (page->>'enrolled')::boolean or (page->>'entryCents')::integer<>267 or (page->>'prizeCents')::integer<>2500
 or jsonb_array_length(page->'predictions')<>0 then raise exception 'Invalid initial tournament state'; end if;
 if has_table_privilege('authenticated','public.paid_tournament_entries','INSERT')
 or has_table_privilege('authenticated','public.paid_tournament_entries','UPDATE')
 or has_function_privilege('authenticated','public.reserve_tournament_order(uuid,uuid,text,uuid)','EXECUTE')
 or has_function_privilege('anon','public.get_finishing_tournament(uuid)','EXECUTE') then raise exception 'Unsafe client permissions'; end if;
 blocked := false;
 begin perform public.reserve_tournament_order(viewer,gen_random_uuid(),'test_handle',target);
 exception when raise_exception then blocked := true; end;
 if not blocked then raise exception 'A user could create a payment reservation directly'; end if;

 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 first_order := public.reserve_tournament_order(viewer,gen_random_uuid(),'test_handle',target);
 second_order := public.reserve_tournament_order(viewer,gen_random_uuid(),'test_handle',target);
 if first_order.id<>second_order.id or first_order.amount_cents<>267 then raise exception 'Reservation is not idempotent or has wrong price'; end if;
 if exists(select 1 from public.paid_tournament_entries where profile_id=viewer and tournament_id=target) then raise exception 'An unpaid order enrolled the player'; end if;
 blocked := false;
 begin perform public.settle_infinitepay_order(first_order.id,'test_tournament_tx','test_tournament_invoice',1,'pix');
 exception when raise_exception then blocked := true; end;
 if not blocked then raise exception 'Wrong payment amount was accepted'; end if;
 perform public.settle_infinitepay_order(first_order.id,'test_tournament_tx','test_tournament_invoice',267,'pix');
 perform public.settle_infinitepay_order(first_order.id,'test_tournament_tx','test_tournament_invoice',267,'pix');
 if (select count(*) from public.paid_tournament_entries where tournament_id=target and profile_id=viewer)<>1 then raise exception 'Settlement duplicated enrollment'; end if;
 blocked := false;
 begin perform public.reserve_tournament_order(viewer,gen_random_uuid(),'test_handle',target);
 exception when raise_exception then blocked := true; end;
 if not blocked then raise exception 'An enrolled player could buy another entry'; end if;

 -- Eleven higher scores exercise both the top ten and the separate own place.
 for participant in select id from public.public_profiles where id<>viewer order by player_id limit 11 loop
  n := n+1;
  insert into public.infinitepay_orders(profile_id,request_id,handle,kind,quantity,amount_cents,tournament_id,paid_at)
  values(participant.id,gen_random_uuid(),'test_handle','tournament',1,267,target,now()) returning id into test_order;
  insert into public.paid_tournament_entries(tournament_id,profile_id,order_id,correct_answers)
  values(target,participant.id,test_order,n);
 end loop;
 if n<>11 then raise exception 'At least twelve profiles are required for the ranking test'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',account,'role','authenticated')::text,true);
 page := public.get_finishing_tournament(target);
 if not (page->>'enrolled')::boolean or jsonb_array_length(page->'players')<>10 or (page#>>'{ownRank,position}')::integer<>12
 or (page#>>'{players,0,correctAnswers}')::integer<>11 or (page#>>'{ownRank,correctAnswers}')::integer<>0 then raise exception 'Wrong tournament ranking or own place'; end if;
 if page::text like '%"email"%' then raise exception 'Private data leaked into the tournament'; end if;

 -- Existing box delivery still works; no real payment is made in this test.
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 select coalesce((select balance from public.box_balances where profile_id=viewer),0) into initial_boxes;
 first_order := public.reserve_infinitepay_order(viewer,gen_random_uuid(),'test_handle','classic',3,321);
 perform public.settle_infinitepay_order(first_order.id,'test_box_regression_tx','test_box_regression_invoice',321,'pix');
 if (select balance from public.box_balances where profile_id=viewer)<>initial_boxes+3 then raise exception 'Existing box delivery regressed'; end if;
 update public.paid_tournaments set starts_at=now()-interval '1 hour',ends_at=now()-interval '1 hour'+interval '3 days' where id=target;
 blocked := false;
 begin perform public.reserve_tournament_order(viewer,gen_random_uuid(),'test_handle',target);
 exception when raise_exception then blocked := true; end;
 if not blocked then raise exception 'Entry remained open after the start'; end if;
end;
$$;
select 'PASS: paid enrollment, server price, permissions, duplicate protection, top 10 plus own position, cutoff and box regression' as result;
