begin;
-- Activate only for championships starting on or after Monday 26 October.
create table public.liga_week_elimination_rounds (
 week_start date not null references public.arena_weeks(week_start),
 day_id date not null,
 initial_players integer not null check(initial_players>=0),
 daily_cut integer not null check(daily_cut>=0),
 processed_at timestamptz not null default now(),
 primary key(week_start,day_id),
 check(week_start>=date '2026-10-26' and day_id between week_start and week_start+5)
);
create table public.liga_week_eliminations (
 week_start date not null,
 profile_id uuid not null,
 eliminated_on date not null,
 recorded_at timestamptz not null default now(),
 primary key(week_start,profile_id),
 foreign key(week_start,profile_id) references public.liga_week_participants(week_start,profile_id),
 foreign key(week_start,eliminated_on) references public.liga_week_elimination_rounds(week_start,day_id)
);
alter table public.liga_week_elimination_rounds enable row level security;
alter table public.liga_week_eliminations enable row level security;
revoke all on public.liga_week_elimination_rounds,public.liga_week_eliminations from public,anon,authenticated;

create function public.liga_week_daily_cut(p_players integer) returns integer
language sql immutable set search_path=public,pg_temp as $$select greatest(coalesce(p_players,0)-10,0)/6$$;
revoke all on function public.liga_week_daily_cut(integer) from public,anon,authenticated;

create function public.apply_liga_week_eliminations(p_week date,p_today date) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare cut_day date; initial_count integer; cut_count integer; active_count integer;
begin
 if p_week>=date '2026-10-26' and p_today>p_week then
  -- Reuse the fixed Monday roster. Process completed days in chronological order.
  select count(*) into initial_count from public.liga_week_participants where week_start=p_week;
  cut_count:=public.liga_week_daily_cut(initial_count);
  for cut_day in select generate_series(p_week,least(p_week+5,p_today-1),'1 day')::date loop
   if not exists(select 1 from public.liga_week_elimination_rounds where week_start=p_week and day_id=cut_day) then
    -- Wait for the complete day's published results; never skip an unresolved day.
    exit when (select count(*) from public.predictions where day_id=cut_day)<10
     or exists(select 1 from public.predictions where day_id=cut_day and status<>'settled');
    insert into public.liga_week_elimination_rounds(week_start,day_id,initial_players,daily_cut)
     values(p_week,cut_day,initial_count,cut_count);
    select count(*) into active_count from public.liga_week_participants r
     where r.week_start=p_week and not exists(select 1 from public.liga_week_eliminations e where e.week_start=p_week and e.profile_id=r.profile_id);
    insert into public.liga_week_eliminations(week_start,profile_id,eliminated_on)
    select p_week,r.profile_id,cut_day from public.liga_week_participants r
     join public.public_profiles p on p.id=r.profile_id
     left join public.arena_week_scores s on s.week_start=p_week and s.profile_id=r.profile_id and s.day_id<=cut_day
     where r.week_start=p_week and not exists(select 1 from public.liga_week_eliminations e where e.week_start=p_week and e.profile_id=r.profile_id)
     group by r.profile_id,p.player_id
     -- Reverse the weekly ranking: worst points, then worst global position, then greens.
     order by coalesce(sum(s.points),0),min((public.battle_rank_meta(r.profile_id)->>'globalPosition')::bigint) desc,
      coalesce(sum(s.greens),0),p.player_id desc
     limit least(cut_count,greatest(active_count-10,0));
   end if;
  end loop;
  -- Preserve points through the elimination day. Later predictions still count elsewhere.
  update public.arena_week_scores s set points=0,greens=0
   from public.liga_week_eliminations e
   where e.week_start=p_week and s.week_start=e.week_start and s.profile_id=e.profile_id and s.day_id>e.eliminated_on
    and (s.points<>0 or s.greens<>0);
 end if;
end;$$;
revoke all on function public.apply_liga_week_eliminations(date,date) from public,anon,authenticated;

do $$
declare definition text; marker text;
begin
 definition:=pg_get_functiondef('public.refresh_weekly_arena()'::regprocedure);
 marker:='complete:=d>=w+6';
 if position(marker in definition)=0 then raise exception 'Unexpected weekly refresh definition';end if;
 execute replace(definition,marker,'perform public.apply_liga_week_eliminations(w,d);'||chr(10)||'  '||marker);
 definition:=pg_get_functiondef('public.get_arena()'::regprocedure);
 marker:='''position'',position,''points'',points,''greens'',greens,''days'',days';
 if position(marker in definition)=0 then raise exception 'Unexpected weekly standings definition';end if;
 execute replace(definition,marker,marker||',''eliminatedOn'',(select e.eliminated_on from public.liga_week_eliminations e where e.week_start=w and e.profile_id=r.profile_id)');
end $$;
notify pgrst,'reload schema';
commit;
