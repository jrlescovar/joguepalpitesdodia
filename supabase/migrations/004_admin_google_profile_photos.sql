alter table public.public_profiles add column if not exists avatar_url text;
alter table public.public_profiles add column if not exists avatar_synced_login_at timestamptz;
alter table public.public_profiles add column if not exists use_google_avatar boolean not null default true;
alter table public.public_profiles drop constraint if exists valid_google_avatar_url;
alter table public.public_profiles add constraint valid_google_avatar_url check (
  avatar_url is null or avatar_url like 'https://lh3.googleusercontent.com/%'
);

create or replace function public.google_avatar_url(p_auth_user_id uuid)
returns text language sql stable security definer set search_path = public, auth, pg_temp as $$
  select case when coalesce(raw_app_meta_data->>'provider','')='google'
    and coalesce(raw_user_meta_data->>'avatar_url',raw_user_meta_data->>'picture','') like 'https://lh3.googleusercontent.com/%'
    then coalesce(raw_user_meta_data->>'avatar_url',raw_user_meta_data->>'picture')
      || case when position('?' in coalesce(raw_user_meta_data->>'avatar_url',raw_user_meta_data->>'picture'))>0 then '&' else '?' end
      || 'v=' || floor(extract(epoch from coalesce(last_sign_in_at,updated_at)))::bigint
    else null end
  from auth.users where id=p_auth_user_id;
$$;

create or replace function public.sync_google_avatar(target uuid)
returns void language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare auth_id uuid; signed_in_at timestamptz; previous_sync timestamptz; enabled boolean;
begin
  select v.auth_user_id,p.avatar_synced_login_at,p.use_google_avatar into auth_id,previous_sync,enabled
  from public.private_profiles v join public.public_profiles p on p.id=v.profile_id
  where v.profile_id=target;
  select last_sign_in_at into signed_in_at from auth.users where id=auth_id;
  if enabled and signed_in_at is not null and (previous_sync is null or signed_in_at>previous_sync) then
    update public.public_profiles set avatar_url=public.google_avatar_url(auth_id),avatar_synced_login_at=signed_in_at,updated_at=now() where id=target;
  end if;
end;
$$;

revoke execute on function public.google_avatar_url(uuid) from public,anon,authenticated;
revoke execute on function public.sync_google_avatar(uuid) from public,anon,authenticated;

update public.public_profiles p set
  avatar_url=public.google_avatar_url(v.auth_user_id),
  avatar_synced_login_at=u.last_sign_in_at,
  updated_at=now()
from public.private_profiles v left join auth.users u on u.id=v.auth_user_id
where v.profile_id=p.id;

create or replace function public.profile_json(target uuid)
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'uid',p.id,'playerId',p.player_id,'email',v.email,'username',p.username,
    'usernameLower',lower(p.username),'usernameChangedAt',v.username_changed_at,
    'avatarColor',p.avatar_color,'avatarUrl',p.avatar_url,'useGoogleAvatar',p.use_google_avatar,
    'level',p.level,'xp',p.xp,'green',p.green,'red',p.red,
    'greenStreakCurrent',p.green_streak_current,'greenStreakMax',p.green_streak_max,
    'dailyStreakCurrent',p.daily_streak_current,'dailyStreakMax',p.daily_streak_max,
    'lastPlayedDate',p.last_played_prediction,'lastPlayedPrediction',p.last_played_prediction,
    'balance',v.balance,'rankPosition',p.rank_position,'rankChange',p.rank_change)
  from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.id=target;
$$;

create or replace function public.update_profile_with_avatar(p_username text,p_avatar_color text,p_use_google_avatar boolean)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid; old_name text; changed_at timestamptz; name_changed boolean;
begin
  target:=public.own_profile_id();
  if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
  if not public.valid_username(p_username) then raise exception 'Use de 3 a 12 letras, números ou underscore. Nomes oficiais são reservados.'; end if;
  if p_avatar_color not in ('#3b82f6','#22c55e','#ec4899','#a855f7','#ef4444','#f97316','#eab308') then raise exception 'Escolha uma cor disponível.'; end if;
  select p.username,v.username_changed_at into old_name,changed_at from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.id=target for update;
  name_changed:=old_name<>p_username;
  if name_changed and changed_at is not null and now()<changed_at+interval '90 days' then raise exception 'Você ainda não pode trocar o nome novamente.'; end if;
  update public.public_profiles set username=p_username,avatar_color=p_avatar_color,use_google_avatar=p_use_google_avatar,
    avatar_url=case when p_use_google_avatar then avatar_url else null end,
    avatar_synced_login_at=case when p_use_google_avatar and not use_google_avatar then null else avatar_synced_login_at end,
    updated_at=now() where id=target;
  update public.private_profiles set username_changed_at=case when name_changed then now() else username_changed_at end,updated_at=now() where profile_id=target;
  if p_use_google_avatar then perform public.sync_google_avatar(target); end if;
  return public.profile_json(target);
exception when unique_violation then raise exception 'Este nome já está em uso.';
end;
$$;

create or replace function public.get_or_claim_profile()
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid; account_email text;
begin
  if auth.uid() is null then raise exception 'Entre com o Google para continuar.'; end if;
  select profile_id into target from public.private_profiles where auth_user_id=auth.uid();
  if target is null and auth.jwt()->'app_metadata'->>'provider'='google' then
    account_email:=lower(coalesce(auth.jwt()->>'email',''));
    if account_email<>'' then
      select profile_id into target from public.private_profiles where lower(email)=account_email and auth_user_id is null for update;
      if target is not null then update public.private_profiles set auth_user_id=auth.uid(),updated_at=now() where profile_id=target; end if;
    end if;
  end if;
  if target is null then return null; end if;
  perform public.sync_google_avatar(target);
  return public.profile_json(target);
end;
$$;

create or replace function public.claim_or_create_profile(p_username text,p_avatar_color text)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid; account_email text; registrations boolean;
begin
  if auth.uid() is null then raise exception 'Entre com o Google para continuar.'; end if;
  account_email:=lower(coalesce(auth.jwt()->>'email',''));
  if account_email='' then raise exception 'Sua conta Google não informou um e-mail.'; end if;
  select profile_id into target from public.private_profiles where auth_user_id=auth.uid();
  if target is not null then perform public.sync_google_avatar(target); return public.profile_json(target); end if;
  select profile_id into target from public.private_profiles where lower(email)=account_email and auth_user_id is null for update;
  if target is not null then
    update public.private_profiles set auth_user_id=auth.uid(),updated_at=now() where profile_id=target;
    perform public.sync_google_avatar(target); return public.profile_json(target);
  end if;
  select registrations_open into registrations from public.app_config where singleton;
  if account_email<>'admin@example.invalid' and not registrations then raise exception 'Os cadastros ainda não foram liberados. Volte em breve.'; end if;
  if not public.valid_username(p_username) then raise exception 'Use de 3 a 12 letras, números ou underscore. Nomes oficiais são reservados.'; end if;
  if p_avatar_color not in ('#3b82f6','#22c55e','#ec4899','#a855f7','#ef4444','#f97316','#eab308') then raise exception 'Escolha uma cor disponível.'; end if;
  lock table public.public_profiles in share row exclusive mode;
  insert into public.public_profiles(username,avatar_color,rank_position)
    select p_username,p_avatar_color,coalesce(max(rank_position),0)+1 from public.public_profiles returning id into target;
  insert into public.private_profiles(profile_id,auth_user_id,email) values(target,auth.uid(),account_email);
  perform public.sync_google_avatar(target); return public.profile_json(target);
exception when unique_violation then raise exception 'Este nome já está em uso. Escolha outro.';
end;
$$;

create or replace function public.get_ranking_top10()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('uid',id,'playerId',player_id,'username',username,'avatarColor',avatar_color,'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,'green',green,'red',red,'level',level,'xp',xp,'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,'lastPlayedPrediction',last_played_prediction,'rankPosition',calculated_position,'rankChange',rank_change) order by calculated_position),'[]'::jsonb)
  from (select p.*,row_number() over(order by green desc,player_id asc)::integer as calculated_position from public.public_profiles p order by green desc,player_id asc limit 10) ranked;
$$;

create or replace function public.get_public_profile(p_profile_id uuid)
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object('uid',id,'playerId',player_id,'username',username,'avatarColor',avatar_color,'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,'green',green,'red',red,'level',level,'xp',xp,'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,'lastPlayedPrediction',last_played_prediction,'rankPosition',rank_position,'rankChange',rank_change) from public.public_profiles where id=p_profile_id;
$$;

create or replace function public.admin_remove_profile_photo(p_profile_id uuid)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode remover fotos.'; end if;
  update public.public_profiles set avatar_url=null,avatar_synced_login_at=now(),updated_at=now() where id=p_profile_id;
  if not found then raise exception 'Jogador não encontrado.'; end if;
  return jsonb_build_object('ok',true);
end;
$$;

revoke execute on function public.admin_remove_profile_photo(uuid) from public,anon;
grant execute on function public.admin_remove_profile_photo(uuid) to authenticated;
revoke execute on function public.update_profile_with_avatar(text,text,boolean) from public,anon;
grant execute on function public.update_profile_with_avatar(text,text,boolean) to authenticated;
notify pgrst,'reload schema';
