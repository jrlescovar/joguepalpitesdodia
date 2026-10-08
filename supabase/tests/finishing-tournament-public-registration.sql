-- Run inside a transaction and roll back: no test checkout or enrollment remains.
do $$
declare account uuid; profile uuid; tournament uuid; output jsonb; saved public.infinitepay_orders; repeated public.infinitepay_orders; request_id uuid:=gen_random_uuid(); initial_entries integer;
begin
 select id into tournament from public.paid_tournaments where enabled and starts_at>now() order by created_at desc limit 1;
 select v.auth_user_id,p.id into account,profile from public.private_profiles v join public.public_profiles p on p.id=v.profile_id
 where p.player_id<>1000001 and v.auth_user_id is not null and not exists(select 1 from public.paid_tournament_entries e where e.tournament_id=tournament and e.profile_id=p.id) order by p.player_id limit 1;
 if account is null or tournament is null then raise exception 'Missing ordinary player or upcoming tournament'; end if;
 select count(*) into initial_entries from public.paid_tournament_entries where tournament_id=tournament;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',account,'role','authenticated')::text,true);
 output:=public.get_finishing_tournament();
 if output is null or output->>'name'<>'Torneio de Finalização' or not (output->>'registrationOpen')::boolean or (output->>'enrolled')::boolean then raise exception 'Ordinary player cannot see open registration'; end if;
 if public.get_finishing_tournament(tournament) is null then raise exception 'Explicit ID read failed'; end if;
 if (output->>'entryCents')::integer<>267 or (output->>'prizeCents')::integer<>267*initial_entries then raise exception 'Entry price or current pool changed'; end if;
 if has_function_privilege('anon','public.get_finishing_tournament(uuid)','execute') or has_function_privilege('authenticated','public.reserve_tournament_order(uuid,uuid,text,uuid)','execute') then raise exception 'Payment or anonymous access widened'; end if;
 begin
  perform public.reserve_tournament_order(profile,request_id,'release_test',tournament);
  raise exception 'Direct authenticated reservation unexpectedly accepted';
 exception when raise_exception then if sqlerrm<>'Acesso negado.' then raise; end if;
 end;
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 saved:=public.reserve_tournament_order(profile,request_id,'release_test',tournament);
 if saved.kind<>'tournament' or saved.amount_cents<>267 or saved.quantity<>1 or saved.tournament_id<>tournament or saved.paid_at is not null then raise exception 'Incorrect tournament checkout'; end if;
 repeated:=public.reserve_tournament_order(profile,request_id,'release_test',tournament);
 if repeated.id<>saved.id then raise exception 'Reservation retry created another order'; end if;
 if exists(select 1 from public.paid_tournament_entries where tournament_id=tournament and profile_id=profile) then raise exception 'Unpaid checkout enrolled player'; end if;
 if (select count(*) from public.paid_tournament_entries where tournament_id=tournament)<>initial_entries then raise exception 'Existing participants changed'; end if;
end;
$$;
