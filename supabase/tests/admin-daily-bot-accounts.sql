-- Run after the accounts-only migration, inside a transaction and roll back.
create temporary table bot_test_profiles_before as select id,to_jsonb(p) as value from public.public_profiles p;
create temporary table bot_test_picks_before as select profile_id,prediction_day,slot,to_jsonb(p) as value from public.picks p;
select set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'email',
  (select owner_email from public.app_config where singleton))::text,true);

do $$
declare first_player uuid; second_player uuid; state jsonb; blocked boolean:=false;
begin
  select id into first_player from public.public_profiles order by player_id limit 1;
  select id into second_player from public.public_profiles order by player_id offset 1 limit 1;
  if first_player is null or second_player is null then raise exception 'Fixtures require two profiles.'; end if;
  state:=public.get_admin_daily_bots();
  if (state->>'enabled')::boolean or (state->>'ready')::boolean then raise exception 'Automation was enabled.'; end if;
  perform public.admin_add_daily_bot(first_player);
  perform public.admin_add_daily_bot(first_player);
  perform public.admin_add_daily_bot(second_player);
  if (select count(*) from public.daily_bot_accounts)<>2 then raise exception 'Duplicate bot accounts.'; end if;
  state:=public.get_admin_daily_bots();
  if jsonb_array_length(state->'accounts')<>2 or state->'accounts'->0->>'uid' is null then raise exception 'Missing accounts in admin state.'; end if;
  if state->'accounts'->0->>'todayPicks' is null then raise exception 'Missing daily progress.'; end if;
  begin perform public.admin_add_daily_bot('00000000-0000-0000-0000-000000000000');
  exception when others then blocked:=sqlerrm='Jogador não encontrado.'; end;
  if not blocked then raise exception 'Invalid account accepted.'; end if;
  blocked:=false;
  begin perform public.admin_set_daily_bots_enabled(true);
  exception when others then blocked:=sqlerrm='A ativação dos palpites automáticos ainda está pendente.'; end;
  if not blocked or (select enabled from public.daily_bot_settings where singleton) then raise exception 'Pending automation can be activated.'; end if;
  perform public.admin_remove_daily_bot(first_player);
  perform public.admin_remove_daily_bot(first_player);
  if (select count(*) from public.daily_bot_accounts)<>1 then raise exception 'Removing an account failed.'; end if;
end;
$$;

select set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'email','ordinary-player@example.test')::text,true);
do $$
declare blocked integer:=0;
begin
  begin perform public.get_admin_daily_bots(); exception when others then if sqlerrm='Somente o proprietário pode administrar bots.' then blocked:=blocked+1; end if; end;
  begin perform public.admin_add_daily_bot('00000000-0000-0000-0000-000000000000'); exception when others then if sqlerrm='Somente o proprietário pode administrar bots.' then blocked:=blocked+1; end if; end;
  begin perform public.admin_remove_daily_bot('00000000-0000-0000-0000-000000000000'); exception when others then if sqlerrm='Somente o proprietário pode administrar bots.' then blocked:=blocked+1; end if; end;
  begin perform public.admin_set_daily_bots_enabled(true); exception when others then if sqlerrm='Somente o proprietário pode administrar bots.' then blocked:=blocked+1; end if; end;
  if blocked<>4 then raise exception 'Non-admin bot access allowed.'; end if;
  if has_table_privilege('authenticated','public.daily_bot_accounts','SELECT')
    or has_table_privilege('authenticated','public.daily_bot_accounts','INSERT')
    or has_table_privilege('authenticated','public.daily_bot_settings','UPDATE')
    or has_table_privilege('anon','public.daily_bot_accounts','SELECT')
    or has_function_privilege('anon','public.get_admin_daily_bots()','EXECUTE') then raise exception 'Bot configuration publicly accessible.'; end if;
  if to_regprocedure('public.run_daily_bot_picks()') is not null or exists(select 1 from cron.job where jobname='daily-bot-picks') then raise exception 'A bot worker or scheduler was installed.'; end if;
  if exists(select 1 from public.public_profiles p full join bot_test_profiles_before b using(id) where to_jsonb(p) is distinct from b.value)
    or exists(select 1 from public.picks p full join bot_test_picks_before b using(profile_id,prediction_day,slot) where to_jsonb(p) is distinct from b.value)
    then raise exception 'Bot account configuration changed picks or profiles.'; end if;
end;
$$;
select jsonb_build_object('accounts','add/remove/idempotency passed','permissions','owner only; no public access',
 'automaticPicks','disabled; no worker or cron','existingPicksAndProfiles','unchanged') as validation;
