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

with ranked as (
  select id,row_number() over(order by green desc,player_id asc)::integer as new_position
  from public.public_profiles
)
update public.public_profiles p
set rank_position=r.new_position,rank_change=0,updated_at=now()
from ranked r
where p.id=r.id;

revoke execute on function public.get_ranking_top10() from public, anon;
revoke execute on function public.get_my_rank() from public, anon;
grant execute on function public.get_ranking_top10() to authenticated;
grant execute on function public.get_my_rank() to authenticated;

notify pgrst, 'reload schema';
