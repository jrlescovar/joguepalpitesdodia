-- Aposta do Dia: Supabase/PostgreSQL backend.
-- Run this migration once in a new Supabase project.

create extension if not exists pgcrypto;
create schema if not exists private;

-- Fixed-window limiter for the Data API. It keeps one small row per user/IP and
-- runs before the requested RPC, so abusive traffic never reaches game logic.
create table if not exists private.api_rate_limits (
  identity_key text primary key,
  window_started_at timestamptz not null,
  request_count integer not null check (request_count >= 0)
);

create or replace function public.check_api_request()
returns void language plpgsql security definer set search_path = public, private, auth, pg_temp as $$
declare
  request_method text := current_setting('request.method',true);
  jwt_subject text := current_setting('request.jwt',true)::jsonb->>'sub';
  forwarded_ip text := split_part(coalesce(current_setting('request.headers',true)::jsonb->>'x-forwarded-for','unknown'),',',1);
  request_identity text;
  hits integer;
begin
  if request_method in ('GET','HEAD') or request_method is null or current_setting('transaction_read_only') = 'on' then return; end if;
  request_identity := case
    when jwt_subject is not null and jwt_subject <> '' then 'user:' || jwt_subject
    else 'ip:' || encode(extensions.digest(forwarded_ip,'sha256'),'hex')
  end;

  insert into private.api_rate_limits(identity_key,window_started_at,request_count)
  values(request_identity,now(),1)
  on conflict(identity_key) do update set
    window_started_at=case when private.api_rate_limits.window_started_at < now()-interval '1 minute' then now() else private.api_rate_limits.window_started_at end,
    request_count=case when private.api_rate_limits.window_started_at < now()-interval '1 minute' then 1 else private.api_rate_limits.request_count+1 end
  returning request_count into hits;

  if hits > 60 then
    raise sqlstate 'PGRST' using
      message=json_build_object('code','rate_limit','message','Muitas requisições. Aguarde um minuto e tente novamente.')::text,
      detail=json_build_object('status',429,'status_text','Too Many Requests')::text;
  end if;
end;
$$;

alter role authenticator set pgrst.db_pre_request = 'public.check_api_request';
notify pgrst, 'reload config';

alter default privileges for role postgres in schema public revoke select,insert,update,delete on tables from anon,authenticated,service_role;
alter default privileges for role postgres in schema public revoke execute on functions from anon,authenticated,service_role;
alter default privileges for role postgres in schema public revoke usage,select on sequences from anon,authenticated,service_role;
alter default privileges for role postgres in schema public revoke execute on functions from public;

create sequence if not exists public.player_id_seq start with 1000001;

create table if not exists public.public_profiles (
  id uuid primary key default gen_random_uuid(),
  player_id bigint not null unique default nextval('public.player_id_seq'),
  username text not null,
  avatar_color text not null,
  level integer not null default 1 check (level >= 1),
  xp integer not null default 0 check (xp >= 0),
  green integer not null default 0 check (green >= 0),
  red integer not null default 0 check (red >= 0),
  green_streak_current integer not null default 0 check (green_streak_current >= 0),
  green_streak_max integer not null default 0 check (green_streak_max >= 0),
  daily_streak_current integer not null default 0 check (daily_streak_current >= 0),
  daily_streak_max integer not null default 0 check (daily_streak_max >= 0),
  last_played_prediction date,
  last_settled_prediction date,
  rank_position integer,
  rank_change integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint valid_username check (username ~ '^[A-Za-z0-9_]{3,12}$'),
  constraint valid_avatar_color check (avatar_color in ('#3b82f6','#22c55e','#ec4899','#a855f7','#ef4444','#f97316','#eab308')),
  constraint valid_xp_for_level check (xp < level * 15),
  constraint valid_green_streak check (green_streak_current <= green_streak_max and green_streak_max <= green)
);

create unique index if not exists public_profiles_username_lower_key on public.public_profiles (lower(username));
create index if not exists public_profiles_ranking_idx on public.public_profiles (green desc, player_id asc);

create table if not exists public.private_profiles (
  profile_id uuid primary key references public.public_profiles(id) on delete cascade,
  auth_user_id uuid unique,
  email text not null,
  balance numeric(12,2) not null default 0,
  username_changed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists private_profiles_email_lower_key on public.private_profiles (lower(email));

create table if not exists public.app_config (
  singleton boolean primary key default true check (singleton),
  registrations_open boolean not null default false,
  owner_email text not null default 'admin@example.invalid',
  updated_at timestamptz not null default now()
);
insert into public.app_config(singleton) values (true) on conflict (singleton) do nothing;

create table if not exists public.predictions (
  day_id date primary key,
  title text not null check (char_length(title) between 5 and 120),
  description text not null default '' check (char_length(description) <= 800),
  options jsonb not null,
  closes_at timestamptz not null,
  status text not null default 'open' check (status in ('open','settling','settled')),
  previous_day_id date references public.predictions(day_id),
  winning_option_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  settled_at timestamptz,
  constraint valid_prediction_options check (jsonb_typeof(options) = 'array' and jsonb_array_length(options) between 2 and 4)
);
create index if not exists predictions_active_idx on public.predictions (status, day_id);
create index if not exists predictions_close_idx on public.predictions (closes_at desc);

create table if not exists public.picks (
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  prediction_day date not null references public.predictions(day_id) on delete restrict,
  option_id text not null,
  status text not null default 'pending' check (status in ('pending','green','red')),
  xp_awarded integer not null default 0 check (xp_awarded in (0,25)),
  created_at timestamptz not null default now(),
  settled_at timestamptz,
  primary key (profile_id, prediction_day)
);
create index if not exists picks_prediction_idx on public.picks (prediction_day, profile_id);

alter table public.public_profiles enable row level security;
alter table public.private_profiles enable row level security;
alter table public.app_config enable row level security;
alter table public.predictions enable row level security;
alter table public.picks enable row level security;

drop policy if exists "authenticated read public profiles" on public.public_profiles;
create policy "authenticated read public profiles" on public.public_profiles for select to authenticated using (true);
drop policy if exists "own private profile" on public.private_profiles;
create policy "own private profile" on public.private_profiles for select to authenticated using (auth.uid() = auth_user_id);
drop policy if exists "authenticated read predictions" on public.predictions;
create policy "authenticated read predictions" on public.predictions for select to authenticated using (true);
drop policy if exists "own picks" on public.picks;
create policy "own picks" on public.picks for select to authenticated using (
  profile_id = (select profile_id from public.private_profiles where auth_user_id = auth.uid())
);

revoke all on public.public_profiles, public.private_profiles, public.app_config, public.predictions, public.picks from anon, authenticated;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public, auth, pg_temp as $$
  select lower(coalesce(auth.jwt()->>'email','')) = lower((select owner_email from public.app_config where singleton));
$$;

create or replace function public.valid_username(value text)
returns boolean language sql immutable as $$
  select value ~ '^[A-Za-z0-9_]{3,12}$'
    and lower(value) <> all(array['admin','administrador','suporte','support','firebase','apostadodia','moderador','root','system','oficial']);
$$;

create or replace function public.own_profile_id()
returns uuid language sql stable security definer set search_path = public, auth, pg_temp as $$
  select profile_id from public.private_profiles where auth_user_id = auth.uid();
$$;

create or replace function public.profile_json(target uuid)
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'uid', p.id, 'playerId', p.player_id, 'email', v.email, 'username', p.username,
    'usernameLower', lower(p.username), 'usernameChangedAt', v.username_changed_at,
    'avatarColor', p.avatar_color, 'level', p.level, 'xp', p.xp, 'green', p.green,
    'red', p.red, 'greenStreakCurrent', p.green_streak_current, 'greenStreakMax', p.green_streak_max,
    'dailyStreakCurrent', p.daily_streak_current, 'dailyStreakMax', p.daily_streak_max,
    'lastPlayedDate', p.last_played_prediction, 'lastPlayedPrediction', p.last_played_prediction,
    'balance', v.balance, 'rankPosition', p.rank_position, 'rankChange', p.rank_change
  ) from public.public_profiles p join public.private_profiles v on v.profile_id = p.id where p.id = target;
$$;

create or replace function public.get_my_profile()
returns jsonb language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
declare target uuid;
begin
  target := public.own_profile_id();
  if target is null then return null; end if;
  return public.profile_json(target);
end;
$$;

-- On the first Google login after migration, attach the imported player by
-- verified provider email. A new player still receives null and sees signup.
create or replace function public.get_or_claim_profile()
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid; account_email text;
begin
  if auth.uid() is null then raise exception 'Entre com o Google para continuar.'; end if;
  select profile_id into target from public.private_profiles where auth_user_id = auth.uid();
  if target is null and auth.jwt()->'app_metadata'->>'provider' = 'google' then
    account_email := lower(coalesce(auth.jwt()->>'email',''));
    if account_email <> '' then
      select profile_id into target from public.private_profiles
        where lower(email) = account_email and auth_user_id is null for update;
      if target is not null then
        update public.private_profiles set auth_user_id = auth.uid(), updated_at = now() where profile_id = target;
      end if;
    end if;
  end if;
  if target is null then return null; end if;
  return public.profile_json(target);
end;
$$;

create or replace function public.claim_or_create_profile(p_username text, p_avatar_color text)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid; account_email text; registrations boolean;
begin
  if auth.uid() is null then raise exception 'Entre com o Google para continuar.'; end if;
  account_email := lower(coalesce(auth.jwt()->>'email',''));
  if account_email = '' then raise exception 'Sua conta Google não informou um e-mail.'; end if;
  select profile_id into target from public.private_profiles where auth_user_id = auth.uid();
  if target is not null then return public.profile_json(target); end if;

  select profile_id into target from public.private_profiles where lower(email) = account_email and auth_user_id is null for update;
  if target is not null then
    update public.private_profiles set auth_user_id = auth.uid(), updated_at = now() where profile_id = target;
    return public.profile_json(target);
  end if;

  select registrations_open into registrations from public.app_config where singleton;
  if account_email <> 'admin@example.invalid' and not registrations then
    raise exception 'Os cadastros ainda não foram liberados. Volte em breve.';
  end if;
  if not public.valid_username(p_username) then raise exception 'Use de 3 a 12 letras, números ou underscore. Nomes oficiais são reservados.'; end if;
  if p_avatar_color not in ('#3b82f6','#22c55e','#ec4899','#a855f7','#ef4444','#f97316','#eab308') then raise exception 'Escolha uma cor disponível.'; end if;

  lock table public.public_profiles in share row exclusive mode;
  insert into public.public_profiles(username, avatar_color, rank_position)
    select p_username, p_avatar_color, coalesce(max(rank_position),0)+1 from public.public_profiles
    returning id into target;
  insert into public.private_profiles(profile_id, auth_user_id, email) values (target, auth.uid(), account_email);
  return public.profile_json(target);
exception when unique_violation then
  raise exception 'Este nome já está em uso. Escolha outro.';
end;
$$;

create or replace function public.check_username(p_username text)
returns jsonb language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
declare target uuid; available boolean;
begin
  if not public.valid_username(p_username) then return jsonb_build_object('available',false,'valid',false); end if;
  target := public.own_profile_id();
  select not exists(select 1 from public.public_profiles where lower(username)=lower(p_username) and id is distinct from target) into available;
  return jsonb_build_object('available',available,'valid',true);
end;
$$;

create or replace function public.update_profile(p_username text, p_avatar_color text)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid; old_name text; changed_at timestamptz; name_changed boolean;
begin
  target := public.own_profile_id();
  if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
  if not public.valid_username(p_username) then raise exception 'Use de 3 a 12 letras, números ou underscore. Nomes oficiais são reservados.'; end if;
  if p_avatar_color not in ('#3b82f6','#22c55e','#ec4899','#a855f7','#ef4444','#f97316','#eab308') then raise exception 'Escolha uma cor disponível.'; end if;
  select p.username, v.username_changed_at into old_name, changed_at
    from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.id=target for update;
  name_changed := old_name <> p_username;
  if name_changed and changed_at is not null and now() < changed_at + interval '90 days' then
    raise exception 'Você poderá trocar o nome novamente em %.', to_char(changed_at + interval '90 days','DD/MM/YYYY');
  end if;
  update public.public_profiles set username=p_username, avatar_color=p_avatar_color, updated_at=now() where id=target;
  update public.private_profiles set username_changed_at=case when name_changed then now() else username_changed_at end, updated_at=now() where profile_id=target;
  return public.profile_json(target);
exception when unique_violation then raise exception 'Este nome já está em uso.';
end;
$$;

create or replace function public.get_session()
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object('dayId', to_char(timezone('America/Sao_Paulo',now()),'YYYY-MM-DD'), 'serverTime', floor(extract(epoch from now())*1000), 'admin', public.is_admin());
$$;

create or replace function public.prediction_json(p public.predictions)
returns jsonb language sql immutable as $$
  select jsonb_build_object('dayId',p.day_id,'title',p.title,'description',p.description,'options',p.options,'closesAt',p.closes_at,'status',p.status,'winningOptionId',p.winning_option_id);
$$;

create or replace function public.get_current_prediction()
returns jsonb language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
declare item public.predictions;
begin
  select * into item from public.predictions where status in ('open','settling') order by day_id limit 1;
  if not found then return null; end if;
  return public.prediction_json(item);
end;
$$;

create or replace function public.get_pick(p_day_id date)
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select to_jsonb(x) from (select prediction_day as "dayId", option_id as "optionId", status from public.picks where profile_id=public.own_profile_id() and prediction_day=p_day_id) x;
$$;

create or replace function public.get_last_closed_prediction()
returns text language sql stable security definer set search_path = public, auth, pg_temp as $$
  select day_id::text from public.predictions where closes_at <= now() order by closes_at desc limit 1;
$$;

create or replace function public.award_xp(p_level integer, p_xp integer, p_reward integer)
returns integer[] language plpgsql immutable as $$
declare next_level integer := p_level; next_xp integer := p_xp + p_reward;
begin
  while next_xp >= next_level * 15 loop next_xp := next_xp - next_level * 15; next_level := next_level + 1; end loop;
  return array[next_level,next_xp];
end;
$$;

create or replace function public.submit_pick(p_day_id date, p_option_id text)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid; game public.predictions; player public.public_profiles; progress integer[]; next_streak integer;
begin
  target := public.own_profile_id(); if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
  select * into game from public.predictions where day_id=p_day_id for update;
  if not found or game.status <> 'open' or game.closes_at <= now() then raise exception 'O prazo para palpitar terminou.'; end if;
  if game.previous_day_id is not null and not exists(select 1 from public.predictions where day_id=game.previous_day_id and status='settled') then raise exception 'A aposta anterior ainda está em jogo.'; end if;
  if not exists(select 1 from jsonb_array_elements(game.options) option where option->>'id'=p_option_id) then raise exception 'Escolha uma opção válida.'; end if;
  select * into player from public.public_profiles where id=target for update;
  insert into public.picks(profile_id,prediction_day,option_id) values(target,p_day_id,p_option_id);
  progress := public.award_xp(player.level,player.xp,5);
  next_streak := case when player.last_played_prediction=game.previous_day_id then player.daily_streak_current+1 else 1 end;
  update public.public_profiles set level=progress[1],xp=progress[2],daily_streak_current=next_streak,daily_streak_max=greatest(daily_streak_max,next_streak),last_played_prediction=p_day_id,updated_at=now() where id=target;
  return jsonb_build_object('ok',true);
exception when unique_violation then raise exception 'Você já confirmou seu palpite nesta aposta.';
end;
$$;

create or replace function public.get_ranking_top10()
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('uid',id,'playerId',player_id,'username',username,'avatarColor',avatar_color,'green',green,'red',red,'level',level,'xp',xp,'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,'lastPlayedPrediction',last_played_prediction,'rankPosition',calculated_position,'rankChange',rank_change) order by calculated_position),'[]'::jsonb)
  from (select p.*,row_number() over(order by green desc,player_id asc)::integer as calculated_position from public.public_profiles p order by green desc,player_id asc limit 10) ranked;
$$;

create or replace function public.get_my_rank()
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object('position',calculated_position,'change',rank_change)
  from (select id,rank_change,row_number() over(order by green desc,player_id asc)::integer as calculated_position from public.public_profiles) ranked
  where id=public.own_profile_id();
$$;

create or replace function public.get_public_profile(p_profile_id uuid)
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object('uid',id,'playerId',player_id,'username',username,'avatarColor',avatar_color,'green',green,'red',red,'level',level,'xp',xp,'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,'lastPlayedPrediction',last_played_prediction,'rankPosition',rank_position,'rankChange',rank_change) from public.public_profiles where id=p_profile_id;
$$;

create or replace function public.get_admin_state()
returns jsonb language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode acessar a administração.'; end if;
  return jsonb_build_object(
    'registrationsOpen',(select registrations_open from public.app_config where singleton),
    'predictions',coalesce((select jsonb_agg(item order by (item->>'dayId')::date desc) from (select public.prediction_json(p) item from public.predictions p order by day_id desc limit 31) recent),'[]'::jsonb)
  );
end;
$$;

create or replace function public.set_registrations(p_open boolean)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin if not public.is_admin() then raise exception 'Somente o proprietário pode alterar os cadastros.'; end if; update public.app_config set registrations_open=p_open,updated_at=now() where singleton; return jsonb_build_object('ok',true); end;
$$;

create or replace function public.publish_prediction(p_day_id date,p_title text,p_description text,p_options jsonb,p_closes_at timestamptz)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare previous date; normalized jsonb;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode publicar desafios.'; end if;
  if p_day_id < timezone('America/Sao_Paulo',now())::date then raise exception 'Escolha hoje ou uma data futura.'; end if;
  if char_length(trim(p_title)) not between 5 and 120 or char_length(p_description)>800 then raise exception 'Confira o título e a descrição.'; end if;
  if jsonb_typeof(p_options)<>'array' or jsonb_array_length(p_options) not between 2 and 4 then raise exception 'Informe de 2 a 4 opções diferentes.'; end if;
  select jsonb_agg(jsonb_build_object('id',ordinality::text,'label',trim(value)) order by ordinality) into normalized from jsonb_array_elements_text(p_options) with ordinality;
  if exists(select 1 from jsonb_array_elements_text(p_options) value where trim(value)='' or char_length(value)>100) then raise exception 'Confira as opções.'; end if;
  if (select count(distinct lower(trim(value))) from jsonb_array_elements_text(p_options) value) <> jsonb_array_length(p_options) then raise exception 'As opções precisam ser diferentes.'; end if;
  if p_closes_at<=now() or timezone('America/Sao_Paulo',p_closes_at)::date<>p_day_id then raise exception 'O prazo deve ser futuro e dentro do dia do desafio em Brasília.'; end if;
  select max(day_id) into previous from public.predictions;
  if previous is not null and previous>=p_day_id then raise exception 'Publique os desafios em ordem de data.'; end if;
  insert into public.predictions(day_id,title,description,options,closes_at,previous_day_id) values(p_day_id,trim(p_title),trim(p_description),normalized,p_closes_at,previous);
  return jsonb_build_object('ok',true);
end;
$$;

create or replace function public.settle_prediction(p_day_id date,p_winning_option_id text)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare game public.predictions;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode concluir desafios.'; end if;
  select * into game from public.predictions where day_id=p_day_id for update;
  if not found then raise exception 'Desafio não encontrado.'; end if;
  if game.status='settled' then
    if game.winning_option_id<>p_winning_option_id then raise exception 'O resultado já foi confirmado e não pode mudar.'; end if;
    return jsonb_build_object('ok',true);
  end if;
  if game.closes_at>now() then raise exception 'Aguarde o prazo terminar.'; end if;
  if not exists(select 1 from jsonb_array_elements(game.options) option where option->>'id'=p_winning_option_id) then raise exception 'Resultado inválido.'; end if;

  update public.predictions set status='settling',winning_option_id=p_winning_option_id,updated_at=now() where day_id=p_day_id;
  with results as (
    select p.id, k.option_id=p_winning_option_id as won,
      public.award_xp(p.level,p.xp,case when k.option_id=p_winning_option_id then 25 else 0 end) as progress
    from public.public_profiles p join public.picks k on k.profile_id=p.id
    where k.prediction_day=p_day_id and k.status='pending'
  )
  update public.public_profiles p set
    level=r.progress[1], xp=r.progress[2], green=p.green+(case when r.won then 1 else 0 end), red=p.red+(case when r.won then 0 else 1 end),
    green_streak_current=case when r.won then p.green_streak_current+1 else 0 end,
    green_streak_max=case when r.won then greatest(p.green_streak_max,p.green_streak_current+1) else p.green_streak_max end,
    last_settled_prediction=p_day_id, updated_at=now()
  from results r where p.id=r.id;

  update public.picks set status=case when option_id=p_winning_option_id then 'green' else 'red' end,xp_awarded=case when option_id=p_winning_option_id then 25 else 0 end,settled_at=now() where prediction_day=p_day_id and status='pending';

  with ranked as (select id,row_number() over(order by green desc,player_id asc)::integer as new_position from public.public_profiles)
  update public.public_profiles p set rank_change=coalesce(p.rank_position,r.new_position)-r.new_position,rank_position=r.new_position,updated_at=now() from ranked r where p.id=r.id;

  update public.predictions set status='settled',settled_at=now(),updated_at=now() where day_id=p_day_id;
  return jsonb_build_object('ok',true);
end;
$$;

create or replace function public.get_admin_profile(p_search text)
returns jsonb language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
declare target uuid;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode editar jogadores.'; end if;
  if p_search ~ '^#?[0-9]+$' then select id into target from public.public_profiles where player_id=replace(p_search,'#','')::bigint;
  else select id into target from public.public_profiles where lower(username)=lower(regexp_replace(p_search,'^@','')); end if;
  if target is null then raise exception 'Jogador não encontrado.'; end if;
  return public.profile_json(target);
end;
$$;

create or replace function public.admin_update_profile(p_profile_id uuid,p_username text,p_avatar_color text,p_level integer,p_xp integer,p_green integer,p_red integer,p_green_streak_current integer,p_green_streak_max integer)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode editar jogadores.'; end if;
  if not public.valid_username(p_username) or p_level<1 or p_level>1000 or p_xp<0 or p_xp>=p_level*15 or p_green<0 or p_red<0 or p_green_streak_current<0 or p_green_streak_max<p_green_streak_current or p_green_streak_max>p_green then raise exception 'Confira o nível, XP e os resultados.'; end if;
  update public.public_profiles set username=p_username,avatar_color=p_avatar_color,level=p_level,xp=p_xp,green=p_green,red=p_red,green_streak_current=p_green_streak_current,green_streak_max=p_green_streak_max,updated_at=now() where id=p_profile_id;
  if not found then raise exception 'Jogador não encontrado.'; end if;
  return jsonb_build_object('ok',true);
exception when unique_violation then raise exception 'Este nome já está em uso.';
end;
$$;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.check_api_request() to authenticator;
grant execute on function public.check_api_request() to anon, authenticated;

grant execute on function public.get_session() to authenticated;
grant execute on function public.get_my_profile() to authenticated;
grant execute on function public.get_or_claim_profile() to authenticated;
grant execute on function public.claim_or_create_profile(text,text) to authenticated;
grant execute on function public.check_username(text) to authenticated;
grant execute on function public.update_profile(text,text) to authenticated;
grant execute on function public.get_current_prediction() to authenticated;
grant execute on function public.get_pick(date) to authenticated;
grant execute on function public.get_last_closed_prediction() to authenticated;
grant execute on function public.submit_pick(date,text) to authenticated;
grant execute on function public.get_ranking_top10() to authenticated;
grant execute on function public.get_my_rank() to authenticated;
grant execute on function public.get_public_profile(uuid) to authenticated;
grant execute on function public.get_admin_state() to authenticated;
grant execute on function public.set_registrations(boolean) to authenticated;
grant execute on function public.publish_prediction(date,text,text,jsonb,timestamptz) to authenticated;
grant execute on function public.settle_prediction(date,text) to authenticated;
grant execute on function public.get_admin_profile(text) to authenticated;
grant execute on function public.admin_update_profile(uuid,text,text,integer,integer,integer,integer,integer,integer) to authenticated;

-- PostgREST wraps STABLE RPCs in read-only transactions. Mark app reads
-- VOLATILE so the pre-request limiter can count their POST requests.
alter function public.get_session() volatile;
alter function public.get_my_profile() volatile;
alter function public.check_username(text) volatile;
alter function public.get_current_prediction() volatile;
alter function public.get_pick(date) volatile;
alter function public.get_last_closed_prediction() volatile;
alter function public.get_ranking_top10() volatile;
alter function public.get_my_rank() volatile;
alter function public.get_public_profile(uuid) volatile;
alter function public.get_admin_state() volatile;
alter function public.get_admin_profile(text) volatile;
notify pgrst, 'reload schema';

-- Initialize the frozen ranking once. Future positions update only when a result is finalized.
with ranked as (select id,row_number() over(order by green desc,player_id asc)::integer as position from public.public_profiles)
update public.public_profiles p set rank_position=r.position,rank_change=0 from ranked r where p.id=r.id;
