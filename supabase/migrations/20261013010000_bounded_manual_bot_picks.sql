begin;
-- Small committed requests prevent the authenticated role's 8s timeout from
-- rolling back an entire backlog. Keep choice, XP, locks and enrollment rules.
create or replace function public.run_daily_bot_picks_batch(p_limit integer)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
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
              if game.slot=0 and game.day_id=today then
                update public.public_profiles set level=progress[1],xp=progress[2],
                  daily_streak_current=case when player.last_played_prediction=today-1 then player.daily_streak_current+1 else 1 end,
                  last_played_prediction=today,updated_at=now() where id=target;
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
$$;
revoke all on function public.run_daily_bot_picks_batch(integer) from public,anon,authenticated,service_role;
create or replace function public.run_tournament_bot_picks_batch(p_limit integer)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare tournament public.paid_tournaments; game public.paid_tournament_predictions;
 target uuid; chosen text; inserted integer; created integer:=0;
begin
 perform pg_advisory_xact_lock(hashtextextended('daily-bot-picks',0));
 if not (select enabled from public.daily_bot_settings where singleton) then return 0; end if;
 if p_limit<=0 then return 0; end if;
 <<tournaments>>
 for tournament in select t.* from public.paid_tournaments t
  where t.enabled
   and exists(select 1 from public.paid_tournament_entries e join public.daily_bot_accounts b on b.profile_id=e.profile_id where e.tournament_id=t.id)
  order by t.id for share of t
 loop
  -- Keep game-before-entry locks; status excludes already finalized events.
  -- Tournament lock also prevents disabling it while this run submits picks.
  for game in select g.* from public.paid_tournament_predictions g
   where g.tournament_id=tournament.id and g.status='open'
    and g.closes_at>=tournament.starts_at and g.closes_at<tournament.ends_at
   order by g.slot for share of g
  loop
   for target in select e.profile_id from public.paid_tournament_entries e
    join public.daily_bot_accounts b on b.profile_id=e.profile_id
    where e.tournament_id=tournament.id order by e.profile_id for update of e
   loop
    if not exists(select 1 from public.paid_tournament_picks
     where tournament_id=tournament.id and slot=game.slot and profile_id=target) then
     -- Mixed tournaments can have only two choices. Never invent a third.
     chosen:=public.bot_ranked_option(coalesce(game.options,
      '[{"id":"home"},{"id":"draw"},{"id":"away"}]'::jsonb),public.wheel_random_index(1000000)/1000000.0);
     if chosen is null then continue; end if;
     insert into public.paid_tournament_picks(tournament_id,slot,profile_id,option_id)
      values(tournament.id,game.slot,target,chosen) on conflict do nothing;
     get diagnostics inserted=row_count;
     if inserted=1 then
      insert into public.tournament_bot_pick_log(tournament_id,slot,profile_id) values(tournament.id,game.slot,target);
      created:=created+1;
      exit tournaments when created>=p_limit;
     end if;
    end if;
   end loop;
  end loop;
 end loop;
 -- Tournament submissions award no XP, greens, daily streak or global points.
 return created;
end;
$$;
revoke all on function public.run_tournament_bot_picks_batch(integer) from public,anon,authenticated,service_role;

create or replace function public.admin_run_bot_pick_batch(p_first boolean default false)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare created integer; tournament_created integer; batch_limit constant integer:=15;
begin
 if not public.is_admin() then raise exception 'Apenas o administrador pode executar os bots.'; end if;
 if not pg_try_advisory_xact_lock(hashtextextended('daily-bot-picks',0)) then
  raise exception 'Os bots já estão executando. Tente novamente em instantes.';
 end if;
 update public.daily_bot_settings set enabled=true where singleton;
 created:=public.run_daily_bot_picks_batch(batch_limit);
 tournament_created:=public.run_tournament_bot_picks_batch(batch_limit-created);
 created:=created+tournament_created;
 update public.daily_bot_settings set enabled=false,last_run_at=now(),
  last_created=case when p_first then created else last_created+created end,
  updated_at=now(),updated_by=auth.uid() where singleton;
 return public.get_admin_daily_bots()||jsonb_build_object('batchCreated',created,'hasMore',created=batch_limit);
end;
$$;
revoke all on function public.admin_run_bot_pick_batch(boolean) from public,anon,service_role;
grant execute on function public.admin_run_bot_pick_batch(boolean) to authenticated;
notify pgrst,'reload schema';
commit;
