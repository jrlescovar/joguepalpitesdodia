begin;

-- Private audit of picks actually created by this routine. Existing picks are
-- never adopted, overwritten or awarded XP a second time.
create table public.daily_bot_pick_log (
  profile_id uuid not null,
  prediction_day date not null,
  slot smallint not null,
  created_at timestamptz not null default now(),
  primary key(profile_id,prediction_day,slot),
  foreign key(profile_id,prediction_day,slot) references public.picks(profile_id,prediction_day,slot) on delete cascade
);
alter table public.daily_bot_pick_log enable row level security;
revoke all on public.daily_bot_pick_log from public,anon,authenticated,service_role;

create function public.run_daily_bot_picks()
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare today date:=public.battle_today(); game public.predictions; player public.public_profiles;
  target uuid; option_id text; option_count integer; progress integer[]; inserted integer; created integer:=0;
begin
  perform pg_advisory_xact_lock(hashtextextended('daily-bot-picks',0));
  if not (select enabled from public.daily_bot_settings where singleton) then return 0; end if;

  -- Match the human submission lock order. Acquire all eligible game locks
  -- before any player locks to avoid cross-game deadlocks with human picks.
  perform 1 from public.predictions where day_id=today and slot between 0 and 9
    and status='open' and closes_at>clock_timestamp() order by slot for update;
  for game in select * from public.predictions where day_id=today and slot between 0 and 9
    and status='open' and closes_at>clock_timestamp() order by slot
  loop
    option_count:=jsonb_array_length(game.options);
    if option_count>0 then
      for target in select profile_id from public.daily_bot_accounts order by profile_id loop
        if game.closes_at>clock_timestamp() and not exists(select 1 from public.picks
          where profile_id=target and prediction_day=today and slot=game.slot) then
          select * into strict player from public.public_profiles where id=target for update;
          option_id:=game.options->public.wheel_random_index(option_count)->>'id';
          insert into public.picks(profile_id,prediction_day,slot,option_id)
            values(target,today,game.slot,option_id) on conflict do nothing;
          get diagnostics inserted=row_count;
          if inserted=1 then
            -- These are the same XP and calendar-streak rules used by
            -- submit_pick_for_game. Normal INSERT triggers handle Arena/battles.
            progress:=public.award_xp(player.level,player.xp,public.pass_xp(5,target));
            if game.slot=0 then
              update public.public_profiles set level=progress[1],xp=progress[2],
                daily_streak_current=case when player.last_played_prediction=today-1 then player.daily_streak_current+1 else 1 end,
                last_played_prediction=today,updated_at=now() where id=target;
            else
              update public.public_profiles set level=progress[1],xp=progress[2],updated_at=now() where id=target;
            end if;
            insert into public.daily_bot_pick_log(profile_id,prediction_day,slot) values(target,today,game.slot);
            created:=created+1;
          end if;
        end if;
      end loop;
    end if;
  end loop;
  update public.daily_bot_settings set last_run_at=now(),last_created=created where singleton;
  return created;
end;
$$;
revoke all on function public.run_daily_bot_picks() from public,anon,authenticated,service_role;

do $$
declare definition text;
begin
  definition:=pg_get_functiondef('public.get_admin_daily_bots()'::regprocedure);
  if position('''ready'',false' in definition)=0 then raise exception 'Definição de configuração inesperada.'; end if;
  execute replace(definition,'''ready'',false','''ready'',true');
end;
$$;

create or replace function public.admin_set_daily_bots_enabled(p_enabled boolean)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode administrar bots.'; end if;
  if p_enabled is null then raise exception 'Informe se os bots devem estar ativos.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('daily-bot-picks',0));
  update public.daily_bot_settings set enabled=p_enabled,updated_at=now(),updated_by=auth.uid() where singleton;
  if p_enabled then perform public.run_daily_bot_picks(); end if;
  return public.get_admin_daily_bots();
end;
$$;

create or replace function public.admin_add_daily_bot(p_profile_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode administrar bots.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('daily-bot-picks',0));
  if not exists(select 1 from public.public_profiles where id=p_profile_id) then raise exception 'Jogador não encontrado.'; end if;
  insert into public.daily_bot_accounts(profile_id,added_by) values(p_profile_id,auth.uid()) on conflict do nothing;
  if (select enabled from public.daily_bot_settings where singleton) then perform public.run_daily_bot_picks(); end if;
  return public.get_admin_daily_bots();
end;
$$;

create or replace function public.admin_remove_daily_bot(p_profile_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode administrar bots.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('daily-bot-picks',0));
  delete from public.daily_bot_accounts where profile_id=p_profile_id;
  return public.get_admin_daily_bots();
end;
$$;
revoke all on function public.admin_set_daily_bots_enabled(boolean),public.admin_add_daily_bot(uuid),public.admin_remove_daily_bot(uuid)
  from public,anon,authenticated;
grant execute on function public.admin_set_daily_bots_enabled(boolean),public.admin_add_daily_bot(uuid),public.admin_remove_daily_bot(uuid)
  to authenticated;

select cron.schedule('daily-bot-picks','* * * * *','select public.run_daily_bot_picks();');
notify pgrst,'reload schema';
commit;
