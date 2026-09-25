begin;

-- Existing predictions have no rankPoints in their options and therefore award zero.
-- New predictions freeze the owner's difficulty points in each option at publication.
alter table public.public_profiles add column if not exists rank_points integer not null default 0 check (rank_points >= 0);
create index if not exists public_profiles_rank_points_idx on public.public_profiles (rank_points desc, player_id asc);

create or replace function public.publish_prediction_ranked(p_day_id date,p_slot smallint,p_title text,p_description text,p_options jsonb,p_rank_points jsonb,p_closes_at timestamptz)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare previous_main date; normalized jsonb;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode publicar desafios.'; end if;
  if p_day_id<timezone('America/Sao_Paulo',now())::date then raise exception 'Escolha hoje ou uma data futura.'; end if;
  if p_slot not between 0 and 2 then raise exception 'Escolha a Aposta do Dia ou uma das duas Extras.'; end if;
  if exists(select 1 from public.predictions where day_id=p_day_id and slot=p_slot) then raise exception 'Essa aposta já foi publicada nesta data.'; end if;
  if p_slot>0 and not exists(select 1 from public.predictions where day_id=p_day_id and slot=p_slot-1) then raise exception 'Publique primeiro a Aposta do Dia e as Extras em ordem.'; end if;
  if char_length(trim(p_title)) not between 5 and 120 or char_length(coalesce(p_description,''))>800 then raise exception 'Confira o título e a descrição.'; end if;
  if coalesce(jsonb_typeof(p_options),'')<>'array' then raise exception 'Informe de 2 a 4 opções diferentes.'; end if;
  if jsonb_array_length(p_options) not between 2 and 4 then raise exception 'Informe de 2 a 4 opções diferentes.'; end if;
  if coalesce(jsonb_typeof(p_rank_points),'')<>'array' then raise exception 'Defina os pontos de cada opção.'; end if;
  if jsonb_array_length(p_rank_points)<>jsonb_array_length(p_options) then raise exception 'Defina os pontos de cada opção.'; end if;
  if exists(select 1 from jsonb_array_elements_text(p_rank_points) value where not case when value ~ '^[0-9]{1,4}$' then value::integer between 1 and 1000 else false end) then raise exception 'Use de 1 a 1000 pontos por opção.'; end if;
  if exists(select 1 from jsonb_array_elements_text(p_options) value where trim(value)='' or char_length(value)>100) then raise exception 'Confira as opções.'; end if;
  if (select count(distinct lower(trim(value))) from jsonb_array_elements_text(p_options) value)<>jsonb_array_length(p_options) then raise exception 'As opções precisam ser diferentes.'; end if;
  select jsonb_agg(jsonb_build_object('id',o.ordinality::text,'label',trim(o.value),'rankPoints',r.value::integer) order by o.ordinality) into normalized
  from jsonb_array_elements_text(p_options) with ordinality o(value,ordinality)
  join jsonb_array_elements_text(p_rank_points) with ordinality r(value,ordinality) using (ordinality);
  if p_closes_at<=now() or timezone('America/Sao_Paulo',p_closes_at)::date<>p_day_id then raise exception 'O prazo deve ser futuro e dentro do dia do desafio em Brasília.'; end if;
  select max(day_id) into previous_main from public.predictions where slot=0 and day_id<p_day_id;
  insert into public.predictions(day_id,slot,title,description,options,closes_at,previous_day_id) values(p_day_id,p_slot,trim(p_title),coalesce(trim(p_description),''),normalized,p_closes_at,previous_main);
  return jsonb_build_object('ok',true);
end;
$$;

create or replace function public.settle_prediction_for_slot(p_day_id date,p_slot smallint,p_winning_option_id text)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare game public.predictions;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode concluir desafios.'; end if;
  select * into game from public.predictions where day_id=p_day_id and slot=p_slot for update;
  if not found then raise exception 'Desafio não encontrado.'; end if;
  if game.status='settled' then
    if game.winning_option_id<>p_winning_option_id then raise exception 'O resultado já foi confirmado e não pode mudar.'; end if;
    return jsonb_build_object('ok',true);
  end if;
  if game.closes_at>now() then raise exception 'Aguarde o prazo terminar.'; end if;
  if not exists(select 1 from jsonb_array_elements(game.options) option where option->>'id'=p_winning_option_id) then raise exception 'Resultado inválido.'; end if;
  update public.predictions set status='settling',winning_option_id=p_winning_option_id,updated_at=now() where day_id=p_day_id and slot=p_slot;
  with results as (
    select p.id,k.option_id=p_winning_option_id as won,
      coalesce((select (o->>'rankPoints')::integer from jsonb_array_elements(game.options) o where o->>'id'=k.option_id),0) as awarded_rank_points,
      public.award_xp(p.level,p.xp,case when k.option_id=p_winning_option_id then 25 else 0 end) as progress
    from public.public_profiles p join public.picks k on k.profile_id=p.id
    where k.prediction_day=p_day_id and k.slot=p_slot and k.status='pending'
  )
  update public.public_profiles p set
    level=r.progress[1],xp=r.progress[2],rank_points=p.rank_points+(case when r.won then r.awarded_rank_points else 0 end),green=p.green+(case when r.won then 1 else 0 end),red=p.red+(case when r.won then 0 else 1 end),
    green_streak_current=case when r.won then p.green_streak_current+1 else 0 end,
    green_streak_max=case when r.won then greatest(p.green_streak_max,p.green_streak_current+1) else p.green_streak_max end,
    last_settled_prediction=p_day_id,updated_at=now()
  from results r where p.id=r.id;
  update public.picks set status=case when option_id=p_winning_option_id then 'green' else 'red' end,xp_awarded=case when option_id=p_winning_option_id then 25 else 0 end,settled_at=now() where prediction_day=p_day_id and slot=p_slot and status='pending';
  with ranked as (select id,row_number() over(order by green desc,public.total_xp(level,xp) desc,player_id asc)::integer as new_position from public.public_profiles)
  update public.public_profiles p set rank_change=coalesce(p.rank_position,r.new_position)-r.new_position,rank_position=r.new_position,updated_at=now() from ranked r where p.id=r.id;
  update public.predictions set status='settled',settled_at=now(),updated_at=now() where day_id=p_day_id and slot=p_slot;
  return jsonb_build_object('ok',true);
end;
$$;

create or replace function public.profile_json(target uuid)
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'uid',p.id,'playerId',p.player_id,'email',v.email,'username',p.username,
    'usernameLower',lower(p.username),'usernameChangedAt',v.username_changed_at,
    'avatarColor',p.avatar_color,'avatarUrl',p.avatar_url,'useGoogleAvatar',p.use_google_avatar,
    'level',p.level,'xp',p.xp,'rankPoints',p.rank_points,'green',p.green,'red',p.red,
    'greenStreakCurrent',p.green_streak_current,'greenStreakMax',p.green_streak_max,
    'dailyStreakCurrent',p.daily_streak_current,'dailyStreakMax',p.daily_streak_max,
    'lastPlayedDate',p.last_played_prediction,'lastPlayedPrediction',p.last_played_prediction,
    'balance',v.balance,'rankPosition',p.rank_position,'rankChange',p.rank_change)
  from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.id=target;
$$;

create or replace function public.get_public_profile(p_profile_id uuid)
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object('uid',id,'playerId',player_id,'username',username,'avatarColor',avatar_color,'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,'green',green,'red',red,'level',level,'xp',xp,'rankPoints',rank_points,'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,'lastPlayedPrediction',last_played_prediction,'rankPosition',rank_position,'rankChange',rank_change) from public.public_profiles where id=p_profile_id;
$$;

create or replace function public.get_global_rank_top10()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'uid',id,'playerId',player_id,'username',username,'avatarColor',avatar_color,
    'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,
    'rankPoints',rank_points,'position',position,
    'green',green,'red',red,'level',level,'xp',xp,
    'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,
    'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,
    'lastPlayedPrediction',last_played_prediction
  ) order by position),'[]'::jsonb)
  from (
    select p.*,row_number() over(order by rank_points desc,player_id asc)::integer as position
    from public.public_profiles p order by rank_points desc,player_id asc limit 10
  ) ranked;
$$;
revoke execute on function public.publish_prediction_for_slot(date,smallint,text,text,jsonb,timestamptz) from public,anon,authenticated;
revoke execute on function public.publish_prediction_ranked(date,smallint,text,text,jsonb,jsonb,timestamptz) from public,anon,authenticated;
revoke execute on function public.get_global_rank_top10() from public,anon,authenticated;
grant execute on function public.publish_prediction_ranked(date,smallint,text,text,jsonb,jsonb,timestamptz) to authenticated;
grant execute on function public.get_global_rank_top10() to authenticated;
notify pgrst,'reload schema';
commit;
