begin;
-- The initial tournament is a private preview for the fixed owner player ID.
-- Do not use a mutable display name or a client-supplied profile ID for access.
do $$
declare definition text; anchor text;
begin
 definition := pg_get_functiondef('public.get_finishing_tournament(uuid)'::regprocedure);
 anchor := 'if viewer is null then raise exception ''Entre na sua conta e crie seu perfil.''; end if;';
 if position(anchor in definition)=0 then raise exception 'Unexpected tournament read definition'; end if;
 definition := replace(definition,anchor,anchor || chr(10) ||
  ' if not exists(select 1 from public.public_profiles where id=viewer and player_id=1000001) then return null; end if;');
 execute definition;

 definition := pg_get_functiondef('public.reserve_tournament_order(uuid,uuid,text,uuid)'::regprocedure);
 anchor := 'if not found then raise exception ''Perfil não encontrado.''; end if;';
 if position(anchor in definition)=0 then raise exception 'Unexpected tournament reservation definition'; end if;
 definition := replace(definition,anchor,anchor || chr(10) ||
  ' if not exists(select 1 from public.public_profiles where id=p_profile_id and player_id=1000001) then raise exception ''Torneios em breve.''; end if;');
 execute definition;
end;
$$;
revoke all on function public.get_finishing_tournament(uuid) from public,anon,authenticated;
grant execute on function public.get_finishing_tournament(uuid) to authenticated;
revoke all on function public.reserve_tournament_order(uuid,uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.reserve_tournament_order(uuid,uuid,text,uuid) to service_role;
notify pgrst,'reload schema';
commit;
