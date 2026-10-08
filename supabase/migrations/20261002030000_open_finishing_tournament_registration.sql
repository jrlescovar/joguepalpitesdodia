begin;
-- Release the tournament to every authenticated player with a profile.
-- Checkout reservation and enrollment still require the trusted payment service.
do $$
declare definition text; guard text;
begin
 definition:=pg_get_functiondef('public.get_finishing_tournament(uuid)'::regprocedure);
 guard:=' if not exists(select 1 from public.public_profiles where id=viewer and player_id=1000001) then return null; end if;';
 if position(guard in definition)=0 then raise exception 'Unexpected tournament visibility definition'; end if;
 execute replace(definition,guard,'');

 definition:=pg_get_functiondef('public.reserve_tournament_order(uuid,uuid,text,uuid)'::regprocedure);
 guard:=' if not exists(select 1 from public.public_profiles where id=p_profile_id and player_id=1000001) then raise exception ''Torneios em breve.''; end if;';
 if position(guard in definition)=0 then raise exception 'Unexpected tournament checkout definition'; end if;
 execute replace(definition,guard,'');
end;
$$;
revoke all on function public.get_finishing_tournament(uuid) from public,anon,authenticated;
grant execute on function public.get_finishing_tournament(uuid) to authenticated;
revoke all on function public.reserve_tournament_order(uuid,uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.reserve_tournament_order(uuid,uuid,text,uuid) to service_role;
notify pgrst,'reload schema';
commit;
