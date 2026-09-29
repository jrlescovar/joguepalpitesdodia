begin;
do $$
declare admin_id uuid; admin_auth uuid; player_id uuid; player_auth uuid;
  before_halloween integer; before_classic integer; new_halloween integer; denied boolean:=false;
begin
  select p.id,v.auth_user_id into admin_id,admin_auth
    from public.public_profiles p join public.private_profiles v on v.profile_id=p.id
    where p.player_id=1000001;
  select p.id,v.auth_user_id into player_id,player_auth
    from public.public_profiles p join public.private_profiles v on v.profile_id=p.id
    where p.player_id<>1000001 and v.auth_user_id is not null limit 1;
  if admin_id is null or player_id is null then raise exception 'Perfis de teste ausentes'; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',admin_auth::text,'email',(select owner_email from public.app_config where singleton))::text,true);
  before_halloween:=public.admin_get_halloween_box_balance(player_id);
  before_classic:=public.admin_get_box_balance(player_id);
  new_halloween:=public.admin_grant_halloween_boxes(player_id,2);
  if new_halloween<>before_halloween+2 or public.admin_get_halloween_box_balance(player_id)<>new_halloween then
    raise exception 'Saldo de Halloween incorreto';
  end if;
  if public.admin_get_box_balance(player_id)<>before_classic then raise exception 'Saldo normal alterado'; end if;
  if not exists(select 1 from public.halloween_box_grants where profile_id=player_id and quantity=2 and granted_by=admin_auth) then
    raise exception 'Concessão não registrada';
  end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',player_auth::text,'email','player@example.com')::text,true);
  begin perform public.admin_grant_halloween_boxes(player_id,1);
  exception when others then denied:=true; end;
  if not denied then raise exception 'Jogador comum conseguiu conceder caixas'; end if;
  if has_function_privilege('anon','public.admin_grant_halloween_boxes(uuid,integer)','execute') then
    raise exception 'Anônimo consegue conceder caixas';
  end if;
end;$$;
rollback;
