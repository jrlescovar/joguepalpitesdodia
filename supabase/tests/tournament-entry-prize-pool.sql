do $$
declare viewer uuid; account uuid; extra uuid; output jsonb; baseline integer; purchase public.infinitepay_orders; target uuid:='36b34446-4dcf-4d63-8cf3-5ba8ec8d1113';
begin
 select p.id,v.auth_user_id into viewer,account from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id=1000001;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',account,'role','authenticated')::text,true);
 output:=public.get_finishing_tournament(target);
 baseline:=(output->>'participants')::integer;
 if not (output->>'enrolled')::boolean or baseline<3 or (output->>'prizeCents')::integer<>baseline*267 then raise exception 'Initial enrollment or pool is incorrect'; end if;
 if (select count(*) from public.paid_tournament_entries where tournament_id=target and profile_id in
 ('3334060e-9857-48f3-b7b0-24e1cb3fd657','38e75f8c-eb50-4a3e-8c3c-91b36fef6c65','9c99f617-23be-44fb-9438-cc1566478c18'))<>3 then raise exception 'Requested player missing'; end if;
 if jsonb_array_length(output->'players')<3 then raise exception 'Enrolled players absent from ranking'; end if;
 select id into extra from public.public_profiles where id not in(select profile_id from public.paid_tournament_entries where tournament_id=target) limit 1;
 insert into public.paid_tournament_entries(tournament_id,profile_id,registration_source) values(target,extra,'admin');
 output:=public.get_finishing_tournament(target);
 if (output->>'prizeCents')::integer<>(baseline+1)*267 then raise exception 'Prize does not grow with a new entry'; end if;
 -- Enrollment retries must not increase either participant count or prize.
 insert into public.paid_tournament_entries(tournament_id,profile_id,registration_source) values(target,extra,'admin') on conflict(tournament_id,profile_id) do nothing;
 output:=public.get_finishing_tournament(target);
 if (output->>'participants')::integer<>baseline+1 then raise exception 'Duplicate enrollment inflated pool'; end if;
 if has_table_privilege('authenticated','public.paid_tournament_entries','INSERT') then raise exception 'Client can grant manual enrollment'; end if;
 -- An existing manually granted entry cannot also be purchased.
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 begin
  perform public.reserve_tournament_order(viewer,gen_random_uuid(),'test_handle',target);
  raise exception 'Enrolled owner could purchase entry twice';
 exception when raise_exception then
  if sqlerrm<>'Você já está inscrito neste torneio.' then raise; end if;
 end;
 -- Exercise a normal verified payment after temporarily removing the owner's
 -- manual entry. The surrounding transaction restores all real registrations.
 delete from public.paid_tournament_entries where tournament_id=target and profile_id=viewer;
 purchase:=public.reserve_tournament_order(viewer,gen_random_uuid(),'test_handle',target);
 perform public.settle_infinitepay_order(purchase.id,'test_entry_pool_tx','test_entry_pool_invoice',267,'pix');
 perform public.settle_infinitepay_order(purchase.id,'test_entry_pool_tx','test_entry_pool_invoice',267,'pix');
 if not exists(select 1 from public.paid_tournament_entries where tournament_id=target and profile_id=viewer and registration_source='payment' and order_id=purchase.id) then raise exception 'Verified payment enrollment failed'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',account,'role','authenticated')::text,true);
 output:=public.get_finishing_tournament(target);
 if (output->>'prizeCents')::integer<>(baseline+1)*267 then raise exception 'Payment replay inflated pool'; end if;
end;
$$;
select 'PASS: three requested players enrolled, entry pool grows once, ranking and permissions preserved' as result;
