begin;
-- Bot picks can be submitted in advance. Count event dates through today, not insertion dates.
-- Ordinary-player counters and the public response shape remain unchanged.
create or replace function public.bot_calendar_streak(p_profile_id uuid,p_today date default public.battle_today())
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
 if not exists(select 1 from public.daily_bot_accounts where profile_id=p_profile_id) then return null;end if;
 with days as (
  select prediction_day from public.picks
  where profile_id=p_profile_id and slot=0 and prediction_day<=p_today
 ), numbered as (
  select prediction_day,prediction_day+(row_number() over(order by prediction_day desc))::integer as island from days
 )
 select jsonb_build_object('current',count(*)::integer,'lastDay',max(prediction_day)) into result
 from numbered where island=(select max(prediction_day)+1 from days);
 return result;
end $$;
revoke all on function public.bot_calendar_streak(uuid,date) from public,anon,authenticated,service_role;

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
    'dailyStreakCurrent',coalesce((public.bot_calendar_streak(id)->>'current')::integer,daily_streak_current),
    'lastPlayedPrediction',coalesce((public.bot_calendar_streak(id)->>'lastDay')::date,last_played_prediction)
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
    'dailyStreakCurrent',coalesce((public.bot_calendar_streak(p.id)->>'current')::integer,p.daily_streak_current),
    'lastPlayedPrediction',coalesce((public.bot_calendar_streak(p.id)->>'lastDay')::date,p.last_played_prediction)
  )
  from public.public_profiles p where p.id = public.own_profile_id();
$function$
;

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
    'dailyStreakCurrent',coalesce((public.bot_calendar_streak(id)->>'current')::integer,daily_streak_current),
    'lastPlayedPrediction',coalesce((public.bot_calendar_streak(id)->>'lastDay')::date,last_played_prediction),'rankPosition',rank_position,'rankChange',rank_change
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
    'green',green,'red',red,'level',level,'xp',xp,'greenStreakCurrent',green_streak_current,'greenStreakMax',green_streak_max, 'redStreakCurrent',public.red_streak_value(username,false),'redStreakMax',public.red_streak_value(username,true),'dailyStreakCurrent',coalesce((public.bot_calendar_streak(id)->>'current')::integer,daily_streak_current),'lastPlayedPrediction',coalesce((public.bot_calendar_streak(id)->>'lastDay')::date,last_played_prediction),'rankPosition',calculated_position,'rankChange',rank_change) order by calculated_position),'[]'::jsonb)
  from (
    select p.*,row_number() over(order by green desc,public.total_xp(level,xp) desc,player_id asc)::integer as calculated_position
    from public.public_profiles p
    order by green desc,public.total_xp(level,xp) desc,player_id asc limit 10
  ) ranked;
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
    'dailyStreakCurrent',coalesce((public.bot_calendar_streak(p.id)->>'current')::integer,p.daily_streak_current),
    'lastPlayedDate',coalesce((public.bot_calendar_streak(p.id)->>'lastDay')::date,p.last_played_prediction),'lastPlayedPrediction',coalesce((public.bot_calendar_streak(p.id)->>'lastDay')::date,p.last_played_prediction),
    'balance',v.balance,'rankPosition',p.rank_position,'rankChange',p.rank_change)
  from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.id=target;
$function$
;

CREATE OR REPLACE FUNCTION public.run_daily_bot_picks()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare today date:=public.battle_today(); game public.predictions; player public.public_profiles;
  target uuid; option_id text; option_count integer; progress integer[]; inserted integer; created integer:=0;
  bot_count integer; chosen_count integer; chosen_kinds integer; common_choice text; alternative text;
begin
  perform pg_advisory_xact_lock(hashtextextended('daily-bot-picks',0));
  if not (select enabled from public.daily_bot_settings where singleton) then return 0; end if;

  select count(*) into bot_count from public.daily_bot_accounts;

  -- Owner-triggered bots fill all published events still pending a result,
  -- including elapsed deadlines and earlier dates. Keep game-before-player locks.
  -- Match the human submission lock order. Acquire all eligible game locks
  -- before any player locks to avoid cross-game deadlocks with human picks.
  perform 1 from public.predictions where slot between 0 and 9
    and status='open' order by day_id,slot for update;
  for game in select * from public.predictions where slot between 0 and 9
    and status='open' order by day_id,slot
  loop
    option_count:=jsonb_array_length(game.options);
    if option_count>0 then
      for target in select profile_id from public.daily_bot_accounts order by profile_id loop
        if not exists(select 1 from public.picks
          where profile_id=target and prediction_day=game.day_id and slot=game.slot) then
          select * into strict player from public.public_profiles where id=target for update;
          -- Apply the same safety ceiling to every date, including backfilled games.
            option_id:=public.bot_ranked_option(game.options,public.wheel_random_index(1000000)/1000000.0);
            -- Each bot draws independently. The final missing pick breaks a
            -- unanimous group when a second permitted choice is available.
            if bot_count>1 then
              select count(*),count(distinct p.option_id),min(p.option_id)
                into chosen_count,chosen_kinds,common_choice
              from public.picks p join public.daily_bot_accounts b on b.profile_id=p.profile_id
              where p.prediction_day=game.day_id and p.slot=game.slot;
              if chosen_count=bot_count-1 and chosen_kinds=1 then
                alternative:=public.bot_ranked_option(game.options,public.wheel_random_index(1000000)/1000000.0,common_choice);
                if alternative is not null then option_id:=alternative; end if;
              end if;
            end if;
          -- If every option exceeds the ceiling, skip rather than waste a pick.
          if option_id is not null then
            insert into public.picks(profile_id,prediction_day,slot,option_id)
              values(target,game.day_id,game.slot,option_id) on conflict do nothing;
            get diagnostics inserted=row_count;
            if inserted=1 then
              -- These are the same XP and calendar-streak rules used by
              -- submit_pick_for_game. Normal INSERT triggers handle Arena/battles.
              progress:=public.award_xp(player.level,player.xp,public.pass_xp(5,target));
              if game.slot=0 then
                update public.public_profiles set level=progress[1],xp=progress[2],
                  daily_streak_current=coalesce((public.bot_calendar_streak(target)->>'current')::integer,0),
                  last_played_prediction=(public.bot_calendar_streak(target)->>'lastDay')::date,updated_at=now() where id=target;
              else
                update public.public_profiles set level=progress[1],xp=progress[2],updated_at=now() where id=target;
              end if;
              insert into public.daily_bot_pick_log(profile_id,prediction_day,slot) values(target,game.day_id,game.slot);
              created:=created+1;
            end if;
          end if;
        end if;
      end loop;
    end if;
  end loop;
  perform public.run_tournament_bot_picks();
  update public.daily_bot_settings set last_run_at=now(),last_created=created where singleton;
  return created;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.run_daily_bot_picks_batch(p_limit integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare today date:=public.battle_today(); game public.predictions; player public.public_profiles;
  target uuid; option_id text; option_count integer; progress integer[]; inserted integer; created integer:=0;
  bot_count integer; chosen_count integer; chosen_kinds integer; common_choice text; alternative text;
begin
  perform pg_advisory_xact_lock(hashtextextended('daily-bot-picks',0));
  if not (select enabled from public.daily_bot_settings where singleton) then return 0; end if;

  if p_limit<=0 then return 0; end if;
  select count(*) into bot_count from public.daily_bot_accounts;

  -- Owner-triggered bots fill all published events still pending a result,
  -- including elapsed deadlines and earlier dates. Keep game-before-player locks.
  -- Match the human submission lock order. Acquire all eligible game locks
  -- before any player locks to avoid cross-game deadlocks with human picks.
  perform 1 from public.predictions where slot between 0 and 9
    and status='open' order by day_id,slot for update;
  <<games>>
  for game in select * from public.predictions where slot between 0 and 9
    and status='open' order by day_id,slot
  loop
    option_count:=jsonb_array_length(game.options);
    if option_count>0 then
      for target in select profile_id from public.daily_bot_accounts order by profile_id loop
        if not exists(select 1 from public.picks
          where profile_id=target and prediction_day=game.day_id and slot=game.slot) then
          select * into strict player from public.public_profiles where id=target for update;
          -- Apply the same safety ceiling to every date, including backfilled games.
            option_id:=public.bot_ranked_option(game.options,public.wheel_random_index(1000000)/1000000.0);
            -- Each bot draws independently. The final missing pick breaks a
            -- unanimous group when a second permitted choice is available.
            if bot_count>1 then
              select count(*),count(distinct p.option_id),min(p.option_id)
                into chosen_count,chosen_kinds,common_choice
              from public.picks p join public.daily_bot_accounts b on b.profile_id=p.profile_id
              where p.prediction_day=game.day_id and p.slot=game.slot;
              if chosen_count=bot_count-1 and chosen_kinds=1 then
                alternative:=public.bot_ranked_option(game.options,public.wheel_random_index(1000000)/1000000.0,common_choice);
                if alternative is not null then option_id:=alternative; end if;
              end if;
            end if;
          -- If every option exceeds the ceiling, skip rather than waste a pick.
          if option_id is not null then
            insert into public.picks(profile_id,prediction_day,slot,option_id)
              values(target,game.day_id,game.slot,option_id) on conflict do nothing;
            get diagnostics inserted=row_count;
            if inserted=1 then
              -- These are the same XP and calendar-streak rules used by
              -- submit_pick_for_game. Normal INSERT triggers handle Arena/battles.
              progress:=public.award_xp(player.level,player.xp,public.pass_xp(5,target));
              if game.slot=0 then
                update public.public_profiles set level=progress[1],xp=progress[2],
                  daily_streak_current=coalesce((public.bot_calendar_streak(target)->>'current')::integer,0),
                  last_played_prediction=(public.bot_calendar_streak(target)->>'lastDay')::date,updated_at=now() where id=target;
              else
                update public.public_profiles set level=progress[1],xp=progress[2],updated_at=now() where id=target;
              end if;
              insert into public.daily_bot_pick_log(profile_id,prediction_day,slot) values(target,game.day_id,game.slot);
              created:=created+1;
              exit games when created>=p_limit;
            end if;
          end if;
        end if;
      end loop;
    end if;
  end loop;
  return created;
end;
$function$
;

update public.public_profiles p
set daily_streak_current=(s.streak->>'current')::integer,
    last_played_prediction=(s.streak->>'lastDay')::date
from (select profile_id,public.bot_calendar_streak(profile_id) as streak from public.daily_bot_accounts) s
where p.id=s.profile_id and (p.daily_streak_current,p.last_played_prediction)
 is distinct from ((s.streak->>'current')::integer,(s.streak->>'lastDay')::date);

notify pgrst,'reload schema';
commit;
