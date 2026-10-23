begin;

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
  -- only for the current Brasilia calendar day. Keep game-before-player locks.
  -- Match the human submission lock order. Acquire all eligible game locks
  -- before any player locks to avoid cross-game deadlocks with human picks.
  perform 1 from public.predictions where slot between 0 and 9
    and status='open' and day_id=today order by day_id,slot for update;
  <<games>>
  for game in select * from public.predictions where slot between 0 and 9
    and status='open' and day_id=today order by day_id,slot
  loop
    option_count:=jsonb_array_length(game.options);
    if option_count>0 then
      for target in select profile_id from public.daily_bot_accounts order by profile_id loop
        if not exists(select 1 from public.picks
          where profile_id=target and prediction_day=game.day_id and slot=game.slot) then
          select * into strict player from public.public_profiles where id=target for update;
          -- Keep the existing per-option safety ceiling.
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
  -- only for the current Brasilia calendar day. Keep game-before-player locks.
  -- Match the human submission lock order. Acquire all eligible game locks
  -- before any player locks to avoid cross-game deadlocks with human picks.
  perform 1 from public.predictions where slot between 0 and 9
    and status='open' and day_id=today order by day_id,slot for update;
  for game in select * from public.predictions where slot between 0 and 9
    and status='open' and day_id=today order by day_id,slot
  loop
    option_count:=jsonb_array_length(game.options);
    if option_count>0 then
      for target in select profile_id from public.daily_bot_accounts order by profile_id loop
        if not exists(select 1 from public.picks
          where profile_id=target and prediction_day=game.day_id and slot=game.slot) then
          select * into strict player from public.public_profiles where id=target for update;
          -- Keep the existing per-option safety ceiling.
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


-- For bots, scheduled picks count on their match day, never on their early
-- insertion date. Human activity keeps the existing timestamp-based rule.
create or replace function public.refresh_battle_activity(p_day date)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
 with activity as (
  select p.id,greatest(date '2026-09-25',timezone('America/Sao_Paulo',p.created_at)::date,
   coalesce(case when exists(select 1 from public.daily_bot_accounts b where b.profile_id=p.id)
    then (select max(k.prediction_day) from public.picks k where k.profile_id=p.id and k.prediction_day<=least(p_day,public.battle_today()))
    else (select max(timezone('America/Sao_Paulo',k.created_at)::date) from public.picks k where k.profile_id=p.id)
   end,timezone('America/Sao_Paulo',p.created_at)::date)) last_day
  from public.public_profiles p
 ), expected as (
  select id,greatest(0,p_day-last_day-1) off_streak,(p_day-last_day-1)>=2 protected from activity
 )
 update public.public_profiles p set battle_off_streak=e.off_streak,battle_protected=e.protected
 from expected e where p.id=e.id
  and (p.battle_off_streak is distinct from e.off_streak or p.battle_protected is distinct from e.protected);
end $$;
notify pgrst,'reload schema';
commit;
