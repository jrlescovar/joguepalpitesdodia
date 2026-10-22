begin;
-- Freeze the exact existing medal holders when version 1.0 is released.
create table public.beta_tester_legacy_awards (
 profile_id uuid primary key references public.public_profiles(id) on delete cascade,
 awarded_at timestamptz not null default now()
);
insert into public.beta_tester_legacy_awards(profile_id)
 select id from public.public_profiles p
 where coalesce((public.get_public_profile(p.id)->>'betaTester')::boolean,false);
alter table public.beta_tester_legacy_awards enable row level security;
revoke all on public.beta_tester_legacy_awards from public,anon,authenticated;
create function public.has_legacy_beta_medal(p_profile_id uuid) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.beta_tester_legacy_awards where profile_id=p_profile_id);
$$;
revoke all on function public.has_legacy_beta_medal(uuid) from public,anon,authenticated;
create function public.lock_legacy_beta_medal_awards() returns trigger
language plpgsql set search_path=public,pg_temp as $$
begin
 raise exception 'A edição Beta foi encerrada. Não é possível conceder ou alterar esta medalha.';
end;$$;
revoke all on function public.lock_legacy_beta_medal_awards() from public,anon,authenticated;
create trigger beta_medals_closed before insert or update on public.beta_tester_legacy_awards
 for each row execute function public.lock_legacy_beta_medal_awards();
-- Existing holders persist independently of profile dates or future changes.
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.profile_json(uuid)'::regprocedure);
 if position('timezone(''America/Sao_Paulo'',p.created_at)::date <= date ''2026-10-20''' in definition)=0 then raise exception 'Unexpected private beta eligibility';end if;
 execute replace(definition,'timezone(''America/Sao_Paulo'',p.created_at)::date <= date ''2026-10-20''','public.has_legacy_beta_medal(p.id)');
 definition:=pg_get_functiondef('public.get_public_profile(uuid)'::regprocedure);
 if position('timezone(''America/Sao_Paulo'',created_at)::date <= date ''2026-10-20''' in definition)=0 then raise exception 'Unexpected public beta eligibility';end if;
 execute replace(definition,'timezone(''America/Sao_Paulo'',created_at)::date <= date ''2026-10-20''','public.has_legacy_beta_medal(id)');
end $$;
notify pgrst,'reload schema';
commit;
