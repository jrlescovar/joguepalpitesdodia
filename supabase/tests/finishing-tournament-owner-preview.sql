do $$
declare owner_account uuid; other_account uuid; owner_profile uuid; other_profile uuid; output jsonb;
begin
 select v.auth_user_id,p.id into owner_account,owner_profile from public.private_profiles v join public.public_profiles p on p.id=v.profile_id where p.player_id=1000001;
 select v.auth_user_id,p.id into other_account,other_profile from public.private_profiles v join public.public_profiles p on p.id=v.profile_id where p.player_id<>1000001 and v.auth_user_id is not null limit 1;
 if owner_account is null or other_account is null then raise exception 'Missing test viewers'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner_account,'role','authenticated')::text,true);
 output := public.get_finishing_tournament();
 if output is null or output->>'name'<>'Torneio de Finalização' then raise exception 'Owner preview is hidden'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other_account,'role','authenticated')::text,true);
 if public.get_finishing_tournament() is not null then raise exception 'Tournament leaked to another player'; end if;
 -- The explicit ID must not bypass the preview restriction either.
 if public.get_finishing_tournament('36b34446-4dcf-4d63-8cf3-5ba8ec8d1113') is not null then raise exception 'Explicit ID bypassed preview'; end if;
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 begin
  perform public.reserve_tournament_order(other_profile,gen_random_uuid(),'test_handle','36b34446-4dcf-4d63-8cf3-5ba8ec8d1113');
  raise exception 'Other player can buy the private tournament';
 exception when raise_exception then
  if sqlerrm<>'Torneios em breve.' then raise; end if;
 end;
 perform public.reserve_tournament_order(owner_profile,gen_random_uuid(),'test_handle','36b34446-4dcf-4d63-8cf3-5ba8ec8d1113');
end;
$$;
select 'PASS: owner visible, others hidden even by explicit ID, only owner can reserve entry' as result;
