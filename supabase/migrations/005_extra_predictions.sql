begin;

-- Up to one daily prediction and two extras per Brasilia date.
alter table public.picks drop constraint if exists picks_prediction_day_fkey;
alter table public.predictions drop constraint if exists predictions_previous_day_id_fkey;
alter table public.picks drop constraint if exists picks_pkey;
alter table public.predictions drop constraint if exists predictions_pkey;
alter table public.predictions add column slot smallint not null default 0 check (slot between 0 and 2);
alter table public.picks add column slot smallint not null default 0 check (slot between 0 and 2);
alter table public.predictions add constraint predictions_pkey primary key (day_id,slot);
alter table public.picks add constraint picks_pkey primary key (profile_id,prediction_day,slot);
alter table public.picks add constraint picks_prediction_fkey foreign key (prediction_day,slot) references public.predictions(day_id,slot) on delete restrict;
create index if not exists predictions_day_slot_idx on public.predictions(day_id,slot);

create or replace function public.prediction_json(p public.predictions)
returns jsonb language sql immutable as $$
  select jsonb_build_object('dayId',p.day_id,'slot',p.slot,'title',p.title,'description',p.description,'options',p.options,'closesAt',p.closes_at,'status',p.status,'winningOptionId',p.winning_option_id);
$$;

create or replace function public.get_current_predictions()
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select coalesce(jsonb_agg(public.prediction_json(p) order by p.slot),'[]'::jsonb)
  from public.predictions p
  where p.day_id=(select min(day_id) from public.predictions where status in ('open','settling'));
$$;

create or replace function public.get_pick_for_game(p_day_id date,p_slot smallint)
returns jsonb language sql stable security definer set search_path = public, auth, pg_temp as $$
  select to_jsonb(x) from (select prediction_day as "dayId", slot, option_id as "optionId", status from public.picks where profile_id=public.own_profile_id() and prediction_day=p_day_id and slot=p_slot) x;
$$;

create or replace function public.get_last_closed_prediction()
returns text language sql stable security definer set search_path = public, auth, pg_temp as $$
  select day_id::text from public.predictions where slot=0 and closes_at<=now() order by closes_at desc limit 1;
$$;

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
  progress := public.award_xp(player.level,player.xp,5);
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

create or replace function public.publish_prediction_for_slot(p_day_id date,p_slot smallint,p_title text,p_description text,p_options jsonb,p_closes_at timestamptz)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare previous_main date; normalized jsonb;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode publicar desafios.'; end if;
  if p_day_id<timezone('America/Sao_Paulo',now())::date then raise exception 'Escolha hoje ou uma data futura.'; end if;
  if p_slot not between 0 and 2 then raise exception 'Escolha a Aposta do Dia ou uma das duas Extras.'; end if;
  if exists(select 1 from public.predictions where day_id=p_day_id and slot=p_slot) then raise exception 'Essa aposta já foi publicada nesta data.'; end if;
  if p_slot>0 and not exists(select 1 from public.predictions where day_id=p_day_id and slot=p_slot-1) then raise exception 'Publique primeiro a Aposta do Dia e as Extras em ordem.'; end if;
  if char_length(trim(p_title)) not between 5 and 120 or char_length(coalesce(p_description,''))>800 then raise exception 'Confira o título e a descrição.'; end if;
  if jsonb_typeof(p_options)<>'array' or jsonb_array_length(p_options) not between 2 and 4 then raise exception 'Informe de 2 a 4 opções diferentes.'; end if;
  if exists(select 1 from jsonb_array_elements_text(p_options) value where trim(value)='' or char_length(value)>100) then raise exception 'Confira as opções.'; end if;
  if (select count(distinct lower(trim(value))) from jsonb_array_elements_text(p_options) value)<>jsonb_array_length(p_options) then raise exception 'As opções precisam ser diferentes.'; end if;
  select jsonb_agg(jsonb_build_object('id',ordinality::text,'label',trim(value)) order by ordinality) into normalized from jsonb_array_elements_text(p_options) with ordinality;
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
    select p.id,k.option_id=p_winning_option_id as won,public.award_xp(p.level,p.xp,case when k.option_id=p_winning_option_id then 25 else 0 end) as progress
    from public.public_profiles p join public.picks k on k.profile_id=p.id
    where k.prediction_day=p_day_id and k.slot=p_slot and k.status='pending'
  )
  update public.public_profiles p set
    level=r.progress[1],xp=r.progress[2],green=p.green+(case when r.won then 1 else 0 end),red=p.red+(case when r.won then 0 else 1 end),
    green_streak_current=case when r.won then p.green_streak_current+1 else 0 end,
    green_streak_max=case when r.won then greatest(p.green_streak_max,p.green_streak_current+1) else p.green_streak_max end,
    last_settled_prediction=p_day_id,updated_at=now()
  from results r where p.id=r.id;
  update public.picks set status=case when option_id=p_winning_option_id then 'green' else 'red' end,xp_awarded=case when option_id=p_winning_option_id then 25 else 0 end,settled_at=now() where prediction_day=p_day_id and slot=p_slot and status='pending';
  with ranked as (select id,row_number() over(order by green desc,player_id asc)::integer as new_position from public.public_profiles)
  update public.public_profiles p set rank_change=coalesce(p.rank_position,r.new_position)-r.new_position,rank_position=r.new_position,updated_at=now() from ranked r where p.id=r.id;
  update public.predictions set status='settled',settled_at=now(),updated_at=now() where day_id=p_day_id and slot=p_slot;
  return jsonb_build_object('ok',true);
end;
$$;

create or replace function public.get_admin_state()
returns jsonb language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode acessar a administração.'; end if;
  return jsonb_build_object(
    'registrationsOpen',(select registrations_open from public.app_config where singleton),
    'predictions',coalesce((select jsonb_agg(item order by (item->>'dayId')::date desc,(item->>'slot')::integer asc) from (select public.prediction_json(p) item from public.predictions p order by day_id desc,slot asc limit 93) recent),'[]'::jsonb)
  );
end;
$$;

revoke execute on function public.get_current_prediction() from authenticated;
revoke execute on function public.get_pick(date) from authenticated;
revoke execute on function public.submit_pick(date,text) from authenticated;
revoke execute on function public.publish_prediction(date,text,text,jsonb,timestamptz) from authenticated;
revoke execute on function public.settle_prediction(date,text) from authenticated;
revoke execute on function public.get_current_predictions() from public,anon,authenticated;
revoke execute on function public.get_pick_for_game(date,smallint) from public,anon,authenticated;
revoke execute on function public.submit_pick_for_game(date,smallint,text) from public,anon,authenticated;
revoke execute on function public.publish_prediction_for_slot(date,smallint,text,text,jsonb,timestamptz) from public,anon,authenticated;
revoke execute on function public.settle_prediction_for_slot(date,smallint,text) from public,anon,authenticated;grant execute on function public.get_current_predictions() to authenticated;
grant execute on function public.get_pick_for_game(date,smallint) to authenticated;
grant execute on function public.submit_pick_for_game(date,smallint,text) to authenticated;
grant execute on function public.publish_prediction_for_slot(date,smallint,text,text,jsonb,timestamptz) to authenticated;
grant execute on function public.settle_prediction_for_slot(date,smallint,text) to authenticated;
alter function public.get_current_predictions() volatile;
alter function public.get_pick_for_game(date,smallint) volatile;
alter function public.get_last_closed_prediction() volatile;
alter function public.get_admin_state() volatile;
notify pgrst,'reload schema';

commit;
