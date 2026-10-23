begin;

-- Rank points are a risk signal for bot choices, not match probabilities.
-- Draws remain varied: weight = points^-0.75, with a hard ceiling of 150.
create or replace function public.bot_ranked_option(p_options jsonb,p_roll double precision,p_excluded text default null)
returns text language sql immutable set search_path=public,pg_temp as $$
 with candidates as (
  select option->>'id' as id,ordinal,
   case when jsonb_typeof(option->'rankPoints')='number'
    then (option->>'rankPoints')::double precision else 25 end as points
  from jsonb_array_elements(p_options) with ordinality as entries(option,ordinal)
 ), weights as (
  select id,ordinal,power(points,-0.75) as weight from candidates
  where points between 1 and 150 and id is not null
   and (p_excluded is null or id<>p_excluded)
 ), distribution as (
  select id,ordinal,sum(weight) over(order by ordinal)/sum(weight) over() as threshold
  from weights
 )
 select id from distribution where p_roll>=0 and p_roll<1 and p_roll<threshold
 order by ordinal limit 1;
$$;
revoke all on function public.bot_ranked_option(jsonb,double precision,text) from public,anon,authenticated,service_role;

create or replace function public.run_daily_bot_picks()
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
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
              if game.slot=0 and game.day_id=today then
                update public.public_profiles set level=progress[1],xp=progress[2],
                  daily_streak_current=case when player.last_played_prediction=today-1 then player.daily_streak_current+1 else 1 end,
                  last_played_prediction=today,updated_at=now() where id=target;
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
$$;
revoke all on function public.run_daily_bot_picks() from public,anon,authenticated,service_role;



notify pgrst,'reload schema';
commit;
