do $$
declare target uuid:='671f995b-18bf-4c49-a706-caff6e580e19';
 old_target uuid:='36b34446-4dcf-4d63-8cf3-5ba8ec8d1113';
 account uuid; extra uuid; output jsonb; purchase public.infinitepay_orders; baseline jsonb;
begin
 if (select enabled from public.paid_tournaments where id=old_target) then raise exception 'Old card is still visible'; end if;
 if (select count(*) from public.paid_tournament_entries where tournament_id=target)<>2 then raise exception 'Expected exactly two initial entries'; end if;
 if exists(select 1 from public.paid_tournament_entries where tournament_id=target and (order_id is not null or registration_source<>'admin' or correct_answers<>0)) then raise exception 'Initial entries must be explicit admin registrations'; end if;
 if exists(select 1 from public.paid_tournament_predictions where tournament_id=target) then raise exception 'Unexpected card predictions'; end if;

 for account in select auth_user_id from public.private_profiles where profile_id in
 ('3334060e-9857-48f3-b7b0-24e1cb3fd657','38e75f8c-eb50-4a3e-8c3c-91b36fef6c65') loop
  perform set_config('request.jwt.claims',jsonb_build_object('sub',account,'role','authenticated')::text,true);
  output:=public.get_finishing_tournament();
  if output->>'id'<>target::text or output->>'name'<>'Torneio de Cartões' or output->>'metric'<>'cards'
   or not (output->>'enrolled')::boolean or (output->>'entryCents')::integer<>333
   or (output->>'prizeCents')::integer<>666 or (output->>'predictionsPublished')::boolean
   or jsonb_array_length(output->'predictions')<>0 or jsonb_array_length(output->'players')<>2
   or (output->>'startsAt')::timestamptz<>'2026-10-10T10:00:00-03:00'::timestamptz then
   raise exception 'Seeded account read is incorrect: %',output;
  end if;
  if public.get_finishing_tournament(old_target) is not null then raise exception 'Old tournament remains publicly selectable'; end if;
 end loop;

 select p.id,v.auth_user_id into extra,account from public.public_profiles p
 join public.private_profiles v on v.profile_id=p.id where p.player_id=1000008;
 if extra is null then raise exception 'Missing test viewer'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',account,'role','authenticated')::text,true);
 output:=public.get_finishing_tournament();
 if (output->>'enrolled')::boolean or not (output->>'registrationOpen')::boolean or (output->>'prizeCents')::integer<>666 then raise exception 'Registration closed or stale pool'; end if;
 if has_table_privilege('authenticated','public.paid_tournament_entries','INSERT') then raise exception 'Player can grant entries'; end if;
 baseline:=to_jsonb(p) from public.public_profiles p where p.id=extra;
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 begin
  perform public.reserve_tournament_order('3334060e-9857-48f3-b7b0-24e1cb3fd657',gen_random_uuid(),'test_handle',target);
  raise exception 'Already enrolled player can buy again';
 exception when raise_exception then
  if sqlerrm<>'Você já está inscrito neste torneio.' then raise; end if;
 end;
 begin
  perform public.reserve_tournament_order(extra,gen_random_uuid(),'test_handle',old_target);
  raise exception 'Archived tournament accepts purchase';
 exception when raise_exception then
  if sqlerrm<>'Torneio não encontrado.' then raise; end if;
 end;
 purchase:=public.reserve_tournament_order(extra,gen_random_uuid(),'test_handle',target);
 if purchase.amount_cents<>333 or purchase.tournament_id<>target then raise exception 'Wrong checkout amount/target'; end if;
 if exists(select 1 from public.paid_tournament_entries where tournament_id=target and profile_id=extra) then raise exception 'Unpaid reservation enrolls a player'; end if;
 perform public.settle_infinitepay_order(purchase.id,'cards_registration_test_tx','cards_registration_test_invoice',333,'pix');
 perform public.settle_infinitepay_order(purchase.id,'cards_registration_test_tx','cards_registration_test_invoice',333,'pix');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',account,'role','authenticated')::text,true);
 output:=public.get_finishing_tournament();
 if not (output->>'enrolled')::boolean or (output->>'prizeCents')::integer<>999 or (output->>'participants')::integer<>3 then raise exception 'Payment replay or pool is incorrect'; end if;
 if baseline is distinct from (select to_jsonb(p) from public.public_profiles p where p.id=extra) then raise exception 'Registration changed global stats'; end if;
 if position('t.metric = ''shots''' in pg_get_functiondef('public.get_automatic_result_targets()'::regprocedure))=0
  and position('t.metric=''shots''' in pg_get_functiondef('public.get_automatic_result_targets()'::regprocedure))=0 then raise exception 'Card tournament may use automatic shot settlement'; end if;
end;
$$;
select 'PASS: seeded entries, 666 initial pool, Saturday 10h, no picks, 333 checkout, payment replay and global isolation' as result;
