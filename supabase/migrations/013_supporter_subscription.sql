begin;

-- Stripe is the only writer of subscription state, through a verified webhook.
create table if not exists public.pass_subscriptions (
  profile_id uuid primary key references public.public_profiles(id) on delete cascade,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  status text not null default 'none',
  current_period_ends_at timestamptz,
  cancel_at_period_end boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint pass_subscription_status_check check (status in ('none','active','past_due','unpaid','canceled','paused','incomplete','incomplete_expired'))
);
alter table public.pass_subscriptions enable row level security;
revoke all on public.pass_subscriptions from anon,authenticated;
grant select,insert,update on public.pass_subscriptions to service_role;
grant select on public.private_profiles to service_role;

alter table public.public_profiles add column if not exists pass_border_style text not null default 'none';
alter table public.public_profiles add column if not exists pass_name_style text not null default 'none';
alter table public.public_profiles add constraint pass_border_style_check check (pass_border_style in ('none','blood','monochrome','purple'));
alter table public.public_profiles add constraint pass_name_style_check check (pass_name_style in ('none','blood','monochrome','purple'));
alter table public.picks drop constraint if exists picks_xp_awarded_check;
alter table public.picks add constraint picks_xp_awarded_check check (xp_awarded between 0 and 38);

create or replace function public.pass_active(p_profile_id uuid)
returns boolean language sql stable security definer set search_path = public, auth, pg_temp as $$
  select exists(
    select 1 from public.pass_subscriptions s where s.profile_id=p_profile_id
      and s.status = 'active'
      and s.current_period_ends_at>now()
  );
$$;
revoke execute on function public.pass_active(uuid) from public,anon,authenticated;

create or replace function public.pass_xp(p_base integer,p_profile_id uuid)
returns integer language sql stable security definer set search_path = public, auth, pg_temp as $$
  select case when public.pass_active(p_profile_id) then (p_base*3+1)/2 else p_base end;
$$;
revoke execute on function public.pass_xp(integer,uuid) from public,anon,authenticated;

create or replace function public.get_pass_status()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object(
    'active',public.pass_active(p.id),'status',coalesce(s.status,'none'),
    'periodEndsAt',s.current_period_ends_at,
    'cancelAtPeriodEnd',coalesce(s.cancel_at_period_end,false),
    'borderStyle',case when public.pass_active(p.id) then p.pass_border_style else 'none' end,
    'nameStyle',case when public.pass_active(p.id) then p.pass_name_style else 'none' end
  ) from public.public_profiles p left join public.pass_subscriptions s on s.profile_id=p.id
  where p.id=public.own_profile_id();
$$;
revoke execute on function public.get_pass_status() from public,anon,authenticated;
grant execute on function public.get_pass_status() to authenticated;

create or replace function public.set_pass_styles(p_border_style text,p_name_style text)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid;
begin
  target:=public.own_profile_id();
  if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
  if not public.pass_active(target) then raise exception 'A assinatura precisa estar ativa para personalizar o perfil.'; end if;
  if p_border_style not in ('none','blood','monochrome','purple') or p_name_style not in ('none','blood','monochrome','purple') then
    raise exception 'Escolha um estilo disponível.';
  end if;
  update public.public_profiles set pass_border_style=p_border_style,pass_name_style=p_name_style,updated_at=now() where id=target;
  return public.get_pass_status();
end;
$$;
revoke execute on function public.set_pass_styles(text,text) from public,anon,authenticated;
grant execute on function public.set_pass_styles(text,text) to authenticated;

create or replace function public.submit_pick_for_game(p_day_id date,p_slot smallint,p_option_id text)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid; game public.predictions; player public.public_profiles; progress integer[]; next_streak integer; previous_main date;
begin
  target := public.own_profile_id();
  if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
  select * into game from public.predictions where day_id=p_day_id and slot=p_slot for update;
  if not found or game.status<>'open' or game.closes_at<=now() then raise exception 'O prazo para palpitar terminou.'; end if;
  if not exists(select 1 from jsonb_array_elements(game.options) option where option->>'id'=p_option_id) then raise exception 'Escolha uma opção válida.'; end if;
  select * into player from public.public_profiles where id=target for update;
  insert into public.picks(profile_id,prediction_day,slot,option_id) values(target,p_day_id,p_slot,p_option_id);
  progress := public.award_xp(player.level,player.xp,public.pass_xp(5,target));
  if p_slot=0 then
    select max(day_id) into previous_main from public.predictions where slot=0 and day_id<p_day_id;
    next_streak := case when previous_main is not null and player.last_played_prediction=previous_main then player.daily_streak_current+1 else 1 end;
    update public.public_profiles set level=progress[1],xp=progress[2],daily_streak_current=next_streak,daily_streak_max=greatest(daily_streak_max,next_streak),last_played_prediction=p_day_id,updated_at=now() where id=target;
  else
    update public.public_profiles set level=progress[1],xp=progress[2],updated_at=now() where id=target;
  end if;
  return jsonb_build_object('ok',true);
exception when unique_violation then raise exception 'Você já confirmou seu palpite nesta aposta.';
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
      public.award_xp(p.level,p.xp,case when k.option_id=p_winning_option_id then public.pass_xp(25,p.id) else 0 end) as progress
    from public.public_profiles p join public.picks k on k.profile_id=p.id
    where k.prediction_day=p_day_id and k.slot=p_slot and k.status='pending'
  )
  update public.public_profiles p set
    level=r.progress[1],xp=r.progress[2],rank_points=p.rank_points+(case when r.won then r.awarded_rank_points else 0 end),green=p.green+(case when r.won then 1 else 0 end),red=p.red+(case when r.won then 0 else 1 end),
    green_streak_current=case when r.won then p.green_streak_current+1 else 0 end,
    green_streak_max=case when r.won then greatest(p.green_streak_max,p.green_streak_current+1) else p.green_streak_max end,
    last_settled_prediction=p_day_id,updated_at=now()
  from results r where p.id=r.id;
  update public.picks set status=case when option_id=p_winning_option_id then 'green' else 'red' end,xp_awarded=case when option_id=p_winning_option_id then public.pass_xp(25,profile_id) else 0 end,settled_at=now() where prediction_day=p_day_id and slot=p_slot and status='pending';
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
    'passBorderStyle',case when public.pass_active(p.id) then p.pass_border_style else 'none' end,
    'passNameStyle',case when public.pass_active(p.id) then p.pass_name_style else 'none' end,
    'level',p.level,'xp',p.xp,'rankPoints',p.rank_points,'green',p.green,'red',p.red,
    'greenStreakCurrent',p.green_streak_current,'greenStreakMax',p.green_streak_max,
    'dailyStreakCurrent',p.daily_streak_current,'dailyStreakMax',p.daily_streak_max,
    'lastPlayedDate',p.last_played_prediction,'lastPlayedPrediction',p.last_played_prediction,
    'balance',v.balance,'rankPosition',p.rank_position,'rankChange',p.rank_change)
  from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.id=target;
$$;

create or replace function public.get_public_profile(p_profile_id uuid)
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object('uid',id,'playerId',player_id,'username',username,'avatarColor',avatar_color,'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,'green',green,'red',red,'level',level,'xp',xp,'rankPoints',rank_points,'passBorderStyle',case when public.pass_active(id) then pass_border_style else 'none' end,'passNameStyle',case when public.pass_active(id) then pass_name_style else 'none' end,'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,'lastPlayedPrediction',last_played_prediction,'rankPosition',rank_position,'rankChange',rank_change) from public.public_profiles where id=p_profile_id;
$$;

create or replace function public.get_global_rank_top10()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'uid',id,'playerId',player_id,'username',username,'avatarColor',avatar_color,
    'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,
    'rankPoints',rank_points,'position',position,
    'passBorderStyle',case when public.pass_active(id) then pass_border_style else 'none' end,
    'passNameStyle',case when public.pass_active(id) then pass_name_style else 'none' end,
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

create or replace function public.get_ranking_top10()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('uid',id,'playerId',player_id,'username',username,'avatarColor',avatar_color,'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,'passBorderStyle',case when public.pass_active(id) then pass_border_style else 'none' end,
    'passNameStyle',case when public.pass_active(id) then pass_name_style else 'none' end,
    'green',green,'red',red,'level',level,'xp',xp,'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,'lastPlayedPrediction',last_played_prediction,'rankPosition',calculated_position,'rankChange',rank_change) order by calculated_position),'[]'::jsonb)
  from (
    select p.*,row_number() over(order by green desc,public.total_xp(level,xp) desc,player_id asc)::integer as calculated_position
    from public.public_profiles p
    order by green desc,public.total_xp(level,xp) desc,player_id asc limit 10
  ) ranked;
$$;

notify pgrst,'reload schema';
commit;
