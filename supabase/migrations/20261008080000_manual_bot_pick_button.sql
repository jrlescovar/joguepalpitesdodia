begin;
create function public.admin_run_daily_bots_now()
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
 if not public.is_admin() then raise exception 'Somente o proprietário pode administrar bots.'; end if;
 perform pg_advisory_xact_lock(hashtextextended('daily-bot-picks',0));
 update public.daily_bot_settings set enabled=true where singleton;
 perform public.run_daily_bot_picks();
 update public.daily_bot_settings set enabled=false,updated_at=now(),updated_by=auth.uid() where singleton;
 return public.get_admin_daily_bots();
end;
$$;
revoke all on function public.admin_run_daily_bots_now() from public,anon,authenticated;
grant execute on function public.admin_run_daily_bots_now() to authenticated;
-- Manual mode: adding accounts or opening the panel does not submit picks.
update public.daily_bot_settings set enabled=false,updated_at=now() where singleton;
select cron.unschedule(jobid) from cron.job where jobname='daily-bot-picks';
notify pgrst,'reload schema';
commit;
