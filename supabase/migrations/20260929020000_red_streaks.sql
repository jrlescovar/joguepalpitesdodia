begin;
alter table public.public_profiles add column red_streak_current integer not null default 0 check(red_streak_current>=0),add column red_streak_max integer not null default 0 check(red_streak_max>=red_streak_current);
create function public.recalculate_red_streak(p_id uuid) returns void language sql security definer set search_path=public,pg_temp as $$
 with ordered as (
  select status,row_number() over(order by settled_at nulls first,prediction_day,slot) as n,
  sum(case when status='green' then 1 else 0 end) over(order by settled_at nulls first,prediction_day,slot rows unbounded preceding) as grp
  from public.picks where profile_id=p_id and status in ('green','red')
 ), runs as (select grp,count(*) filter(where status='red')::integer as length,max(n) as latest from ordered group by grp), totals as (
 select coalesce((select length from runs order by latest desc limit 1),0) as current,coalesce(max(length),0) as maximum from runs
 ) update public.public_profiles p set red_streak_current=t.current,red_streak_max=greatest(p.red_streak_max,t.maximum) from totals t where p.id=p_id;
$$;
create function public.track_red_streak() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.status='pending' or (tg_op='UPDATE' and old.status=new.status) then return new; end if;
 if (tg_op='UPDATE' and old.status<>'pending') or exists(select 1 from public.picks k where k.profile_id=new.profile_id and k.status<>'pending' and (k.prediction_day,k.slot)<>(new.prediction_day,new.slot) and k.settled_at>new.settled_at) then
  perform public.recalculate_red_streak(new.profile_id);
 else
  update public.public_profiles set red_streak_current=case when new.status='red' then red_streak_current+1 else 0 end,
    red_streak_max=case when new.status='red' then greatest(red_streak_max,red_streak_current+1) else red_streak_max end where id=new.profile_id;
 end if;
 return new;
end;$$;
create trigger track_red_streak after insert or update of status on public.picks for each row execute function public.track_red_streak();
select public.recalculate_red_streak(id) from public.public_profiles;
create function public.red_streak_value(p_username text,p_max boolean) returns integer language sql stable security definer set search_path=public,pg_temp as $$
 select case when p_max then red_streak_max else red_streak_current end from public.public_profiles where username=p_username;
$$;
revoke all on function public.recalculate_red_streak(uuid),public.track_red_streak(),public.red_streak_value(text,boolean) from public,anon,authenticated;
CREATE OR REPLACE FUNCTION public.get_public_profile(p_profile_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  select jsonb_build_object(
    'uid',id,'playerId',player_id,'username',username,'usernameFont',public.username_font_for(username),
    'avatarColor',avatar_color,'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,
    'green',green,'red',red,'level',level,'xp',xp,'rankPoints',rank_points,
    'betaTester',timezone('America/Sao_Paulo',created_at)::date <= date '2026-10-20',
    'supporterActive',public.pass_active(id),
    'passBorderStyle',case when public.box_style_allowed(id,'frame',pass_border_style) then pass_border_style else 'none' end,
    'passNameStyle',case when public.box_style_allowed(id,'name',pass_name_style) then pass_name_style else 'none' end,
    'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max, 'redStreakCurrent',public.red_streak_value(username,false),'redStreakMax',public.red_streak_value(username,true),
    'dailyStreakCurrent',daily_streak_current,
    'lastPlayedPrediction',last_played_prediction,'rankPosition',rank_position,'rankChange',rank_change
  ) from public.public_profiles where id=p_profile_id;
$function$
;
CREATE OR REPLACE FUNCTION public.get_ranking_top10()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object('uid',id,'playerId',player_id,'username',username,'usernameFont',public.username_font_for(username),'avatarColor',avatar_color,'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,'passBorderStyle',case when public.box_style_allowed(id,'frame',pass_border_style) then pass_border_style else 'none' end,
    'passNameStyle',case when public.box_style_allowed(id,'name',pass_name_style) then pass_name_style else 'none' end,
    'green',green,'red',red,'level',level,'xp',xp,'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max, 'redStreakCurrent',public.red_streak_value(username,false),'redStreakMax',public.red_streak_value(username,true),'dailyStreakCurrent',daily_streak_current,'lastPlayedPrediction',last_played_prediction,'rankPosition',calculated_position,'rankChange',rank_change) order by calculated_position),'[]'::jsonb)
  from (
    select p.*,row_number() over(order by green desc,public.total_xp(level,xp) desc,player_id asc)::integer as calculated_position
    from public.public_profiles p
    order by green desc,public.total_xp(level,xp) desc,player_id asc limit 10
  ) ranked;
$function$
;
CREATE OR REPLACE FUNCTION public.get_global_rank_top10()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object(
    'uid',id,'playerId',player_id,'username',username,'usernameFont',public.username_font_for(username),'avatarColor',avatar_color,
    'avatarUrl',avatar_url,'useGoogleAvatar',use_google_avatar,
    'rankPoints',rank_points,'position',position,
    'passBorderStyle',case when public.box_style_allowed(id,'frame',pass_border_style) then pass_border_style else 'none' end,
    'passNameStyle',case when public.box_style_allowed(id,'name',pass_name_style) then pass_name_style else 'none' end,
    'green',green,'red',red,'level',level,'xp',xp,
    'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max, 'redStreakCurrent',public.red_streak_value(username,false),'redStreakMax',public.red_streak_value(username,true),
    'dailyStreakCurrent',daily_streak_current,
    'lastPlayedPrediction',last_played_prediction
  ) order by position),'[]'::jsonb)
  from (
    select p.*,row_number() over(order by rank_points desc,player_id asc)::integer as position
    from public.public_profiles p order by rank_points desc,player_id asc limit 10
  ) ranked;
$function$
;
CREATE OR REPLACE FUNCTION public.get_my_global_rank()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  select jsonb_build_object(
    'uid',p.id,'playerId',p.player_id,'username',p.username,'usernameFont',public.username_font_for(p.username),
    'avatarColor',p.avatar_color,'avatarUrl',p.avatar_url,
    'useGoogleAvatar',p.use_google_avatar,'rankPoints',p.rank_points,
    'position',1 + (
      select count(*) from public.public_profiles other
      where other.rank_points > p.rank_points
        or (other.rank_points = p.rank_points and other.player_id < p.player_id)
    ),
    'green',p.green,'red',p.red,'level',p.level,'xp',p.xp,
    'greenStreakCurrent',p.green_streak_current,'greenStreakMax',p.green_streak_max, 'redStreakCurrent',public.red_streak_value(p.username,false),'redStreakMax',public.red_streak_value(p.username,true),
    'dailyStreakCurrent',p.daily_streak_current,
    'lastPlayedPrediction',p.last_played_prediction
  )
  from public.public_profiles p where p.id = public.own_profile_id();
$function$
;
CREATE OR REPLACE FUNCTION public.profile_json(target uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
  select jsonb_build_object(
    'uid',p.id,'playerId',p.player_id,'email',v.email,'username',p.username,'usernameFont',public.username_font_for(p.username),
    'usernameLower',lower(p.username),'usernameChangedAt',v.username_changed_at,
    'avatarColor',p.avatar_color,'avatarUrl',p.avatar_url,'useGoogleAvatar',p.use_google_avatar,
    'passBorderStyle',case when public.box_style_allowed(p.id,'frame',p.pass_border_style) then p.pass_border_style else 'none' end,
    'passNameStyle',case when public.box_style_allowed(p.id,'name',p.pass_name_style) then p.pass_name_style else 'none' end,
    'betaTester',timezone('America/Sao_Paulo',p.created_at)::date <= date '2026-10-20',
    'level',p.level,'xp',p.xp,'rankPoints',p.rank_points,'green',p.green,'red',p.red,
    'greenStreakCurrent',p.green_streak_current,'greenStreakMax',p.green_streak_max, 'redStreakCurrent',public.red_streak_value(p.username,false),'redStreakMax',public.red_streak_value(p.username,true),
    'dailyStreakCurrent',p.daily_streak_current,
    'lastPlayedDate',p.last_played_prediction,'lastPlayedPrediction',p.last_played_prediction,
    'balance',v.balance,'rankPosition',p.rank_position,'rankChange',p.rank_change)
  from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.id=target;
$function$
;
commit;
