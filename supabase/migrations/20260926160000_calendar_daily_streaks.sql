begin;

-- A sequência diária exige palpites principais em datas consecutivas de Brasília.
-- Um desafio não publicado não transforma dias separados em dias seguidos.
create or replace function public.submit_pick_for_game(p_day_id date,p_slot smallint,p_option_id text)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid; game public.predictions; player public.public_profiles; progress integer[]; next_streak integer;
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
    next_streak := case when player.last_played_prediction=p_day_id-1 then player.daily_streak_current+1 else 1 end;
    update public.public_profiles set level=progress[1],xp=progress[2],daily_streak_current=next_streak,daily_streak_max=greatest(daily_streak_max,next_streak),last_played_prediction=p_day_id,updated_at=now() where id=target;
  else
    update public.public_profiles set level=progress[1],xp=progress[2],updated_at=now() where id=target;
  end if;
  return jsonb_build_object('ok',true);
exception when unique_violation then raise exception 'Você já confirmou seu palpite nesta aposta.';
end;
$$;

revoke execute on function public.submit_pick_for_game(date,smallint,text) from public,anon,authenticated;
grant execute on function public.submit_pick_for_game(date,smallint,text) to authenticated;

-- Recalcula a sequência atual e o recorde a partir das apostas principais reais.
with main_days as (
  select profile_id,prediction_day from public.picks where slot=0
), numbered as (
  select profile_id,prediction_day,
    prediction_day - row_number() over (partition by profile_id order by prediction_day)::integer as run_key
  from main_days
), runs as (
  select profile_id,count(*)::integer as run_length,max(prediction_day) as last_day
  from numbered group by profile_id,run_key
), totals as (
  select profile_id,max(run_length) as max_streak,
    (array_agg(run_length order by last_day desc))[1] as current_streak,
    max(last_day) as last_day
  from runs group by profile_id
), recalculated as (
  select p.id,coalesce(t.current_streak,0) as current_streak,
    coalesce(t.max_streak,0) as max_streak,t.last_day
  from public.public_profiles p left join totals t on t.profile_id=p.id
)
update public.public_profiles p set
  daily_streak_current=r.current_streak,
  daily_streak_max=r.max_streak,
  last_played_prediction=r.last_day,
  updated_at=now()
from recalculated r
where p.id=r.id
  and (p.daily_streak_current,p.daily_streak_max,p.last_played_prediction)
    is distinct from (r.current_streak,r.max_streak,r.last_day);

commit;
