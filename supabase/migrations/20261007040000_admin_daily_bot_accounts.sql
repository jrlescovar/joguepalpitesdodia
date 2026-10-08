begin;

-- Configuration only. No scheduler, pick creation, XP or ranking writes.
create table public.daily_bot_settings (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  last_run_at timestamptz,
  last_created integer not null default 0 check (last_created >= 0)
);
insert into public.daily_bot_settings(singleton) values (true);

create table public.daily_bot_accounts (
  profile_id uuid primary key references public.public_profiles(id) on delete cascade,
  added_by uuid,
  created_at timestamptz not null default now()
);
alter table public.daily_bot_settings enable row level security;
alter table public.daily_bot_accounts enable row level security;
revoke all on public.daily_bot_settings,public.daily_bot_accounts from public,anon,authenticated;

create function public.get_admin_daily_bots()
returns jsonb language plpgsql stable security definer set search_path=public,auth,pg_temp as $$
declare today date:=public.battle_today(); result jsonb;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode administrar bots.'; end if;
  select jsonb_build_object('enabled',s.enabled,'ready',false,'dayId',today,
    'lastRunAt',s.last_run_at,'lastCreated',s.last_created,
    'predictionCount',(select count(*) from public.predictions where day_id=today),
    'accounts',(select coalesce(jsonb_agg(public.get_public_profile(b.profile_id) ||
      jsonb_build_object('todayPicks',(select count(*) from public.picks p where p.profile_id=b.profile_id and p.prediction_day=today))
      order by profile.player_id),'[]'::jsonb)
      from public.daily_bot_accounts b join public.public_profiles profile on profile.id=b.profile_id))
    into result from public.daily_bot_settings s where s.singleton;
  return result;
end;
$$;

create function public.admin_add_daily_bot(p_profile_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode administrar bots.'; end if;
  if not exists(select 1 from public.public_profiles where id=p_profile_id) then raise exception 'Jogador não encontrado.'; end if;
  insert into public.daily_bot_accounts(profile_id,added_by) values(p_profile_id,auth.uid()) on conflict (profile_id) do nothing;
  return public.get_admin_daily_bots();
end;
$$;

create function public.admin_remove_daily_bot(p_profile_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode administrar bots.'; end if;
  delete from public.daily_bot_accounts where profile_id=p_profile_id;
  return public.get_admin_daily_bots();
end;
$$;

create function public.admin_set_daily_bots_enabled(p_enabled boolean)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode administrar bots.'; end if;
  raise exception 'A ativação dos palpites automáticos ainda está pendente.';
end;
$$;

revoke all on function public.get_admin_daily_bots(),public.admin_add_daily_bot(uuid),
  public.admin_remove_daily_bot(uuid),public.admin_set_daily_bots_enabled(boolean) from public,anon,authenticated;
grant execute on function public.get_admin_daily_bots(),public.admin_add_daily_bot(uuid),
  public.admin_remove_daily_bot(uuid),public.admin_set_daily_bots_enabled(boolean) to authenticated;
notify pgrst,'reload schema';
commit;
