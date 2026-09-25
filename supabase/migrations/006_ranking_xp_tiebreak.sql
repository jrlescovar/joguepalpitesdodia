begin;

-- The profile stores XP within the current level. Reconstruct lifetime XP so a
-- level-up never lowers a player's position when green totals are tied.
create or replace function public.total_xp(p_level integer,p_xp integer)
returns bigint language sql immutable strict as $$
  select 15::bigint * p_level * (p_level-1) / 2 + p_xp;
$$;
revoke execute on function public.total_xp(integer,integer) from public,anon,authenticated;

create or replace function public.get_ranking_top10()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('uid',id,'playerId',player_id,'username',username,'avatarColor',avatar_color,'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,'green',green,'red',red,'level',level,'xp',xp,'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max,'dailyStreakCurrent',daily_streak_current,'dailyStreakMax',daily_streak_max,'lastPlayedPrediction',last_played_prediction,'rankPosition',calculated_position,'rankChange',rank_change) order by calculated_position),'[]'::jsonb)
  from (
    select p.*,row_number() over(order by green desc,public.total_xp(level,xp) desc,player_id asc)::integer as calculated_position
    from public.public_profiles p
    order by green desc,public.total_xp(level,xp) desc,player_id asc limit 10
  ) ranked;
$$;

create or replace function public.get_my_rank()
returns jsonb language sql volatile security definer set search_path = public, auth, pg_temp as $$
  select jsonb_build_object('position',calculated_position,'change',rank_change)
  from (
    select id,rank_change,row_number() over(order by green desc,public.total_xp(level,xp) desc,player_id asc)::integer as calculated_position
    from public.public_profiles
  ) ranked where id=public.own_profile_id();
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
  with ranked as (select id,row_number() over(order by green desc,public.total_xp(level,xp) desc,player_id asc)::integer as new_position from public.public_profiles)
  update public.public_profiles p set rank_change=coalesce(p.rank_position,r.new_position)-r.new_position,rank_position=r.new_position,updated_at=now() from ranked r where p.id=r.id;
  update public.predictions set status='settled',settled_at=now(),updated_at=now() where day_id=p_day_id and slot=p_slot;
  return jsonb_build_object('ok',true);
end;
$$;

-- Bring stored positions in line with the new tiebreaker immediately.
with ranked as (
  select id,row_number() over(order by green desc,public.total_xp(level,xp) desc,player_id asc)::integer as new_position
  from public.public_profiles
)
update public.public_profiles p
set rank_position=r.new_position,rank_change=0,updated_at=now()
from ranked r where p.id=r.id;

notify pgrst,'reload schema';
commit;
