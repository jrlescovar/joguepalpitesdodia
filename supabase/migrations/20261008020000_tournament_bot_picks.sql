begin;

create table public.tournament_bot_pick_log (
 tournament_id uuid not null,
 slot smallint not null,
 profile_id uuid not null,
 created_at timestamptz not null default now(),
 primary key(tournament_id,slot,profile_id),
 foreign key(tournament_id,slot,profile_id) references public.paid_tournament_picks(tournament_id,slot,profile_id) on delete cascade
);
alter table public.tournament_bot_pick_log enable row level security;
revoke all on public.tournament_bot_pick_log from public,anon,authenticated,service_role;

create function public.run_tournament_bot_picks()
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare tournament public.paid_tournaments; game public.paid_tournament_predictions;
 target uuid; chosen text; inserted integer; created integer:=0;
begin
 perform pg_advisory_xact_lock(hashtextextended('daily-bot-picks',0));
 if not (select enabled from public.daily_bot_settings where singleton) then return 0; end if;
 for tournament in select t.* from public.paid_tournaments t
  where t.enabled and t.ends_at>clock_timestamp()
   and exists(select 1 from public.paid_tournament_entries e join public.daily_bot_accounts b on b.profile_id=e.profile_id where e.tournament_id=t.id)
  order by t.id for share of t
 loop
  -- Same game-before-entry lock order and deadline recheck as human picks.
  -- Tournament lock also prevents disabling it while this run submits picks.
  for game in select g.* from public.paid_tournament_predictions g
   where g.tournament_id=tournament.id and g.status='open'
    and g.closes_at>clock_timestamp() and g.closes_at>=tournament.starts_at and g.closes_at<tournament.ends_at
   order by g.slot for share of g
  loop
   for target in select e.profile_id from public.paid_tournament_entries e
    join public.daily_bot_accounts b on b.profile_id=e.profile_id
    where e.tournament_id=tournament.id order by e.profile_id for update of e
   loop
    if game.closes_at>clock_timestamp() and not exists(select 1 from public.paid_tournament_picks
     where tournament_id=tournament.id and slot=game.slot and profile_id=target) then
     chosen:=(array['home','draw','away'])[public.wheel_random_index(3)+1];
     insert into public.paid_tournament_picks(tournament_id,slot,profile_id,option_id)
      values(tournament.id,game.slot,target,chosen) on conflict do nothing;
     get diagnostics inserted=row_count;
     if inserted=1 then
      insert into public.tournament_bot_pick_log(tournament_id,slot,profile_id) values(tournament.id,game.slot,target);
      created:=created+1;
     end if;
    end if;
   end loop;
  end loop;
 end loop;
 -- Tournament submissions award no XP, greens, daily streak or global points.
 return created;
end;
$$;
revoke all on function public.run_tournament_bot_picks() from public,anon,authenticated,service_role;

do $$
declare definition text; anchor text;
begin
 definition:=pg_get_functiondef('public.run_daily_bot_picks()'::regprocedure);
 anchor:='update public.daily_bot_settings set last_run_at=now(),last_created=created where singleton;';
 if position(anchor in definition)=0 or position('run_tournament_bot_picks' in definition)>0 then raise exception 'Rotina diária inesperada.'; end if;
 execute replace(definition,anchor,'perform public.run_tournament_bot_picks();'||chr(10)||'  '||anchor);

 definition:=pg_get_functiondef('public.get_admin_daily_bots()'::regprocedure);
 anchor:='jsonb_build_object(''todayPicks'',';
 if position(anchor in definition)=0 then raise exception 'Painel de bots inesperado.'; end if;
 execute replace(definition,anchor,
  'jsonb_build_object(''tournamentPicks'',(select count(*) from public.paid_tournament_picks p join public.paid_tournaments t on t.id=p.tournament_id where p.profile_id=b.profile_id and t.enabled and t.ends_at>now()),'
  ||'''tournamentTotal'',(select count(*) from public.paid_tournament_predictions g join public.paid_tournaments t on t.id=g.tournament_id join public.paid_tournament_entries e on e.tournament_id=t.id and e.profile_id=b.profile_id where t.enabled and t.ends_at>now()),''todayPicks'',');
end;
$$;

-- Existing minute scheduler and admin activation/addition now cover both modes.
notify pgrst,'reload schema';
commit;
