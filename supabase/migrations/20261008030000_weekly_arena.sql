begin;
-- Daily crowns and their existing awards remain historical records.
alter table public.arena_entries drop constraint arena_entries_seed_check;
alter table public.arena_entries add constraint arena_entries_seed_check check(seed between 1 and 100);
create table public.arena_weeks (
 week_start date primary key check(extract(isodow from week_start)=1),
 status text not null default 'qualifying' check(status in ('qualifying','knockout','finished')),
 winner_id uuid references public.public_profiles(id), frozen_at timestamptz, finished_at timestamptz
);
create table public.arena_week_scores (
 week_start date references public.arena_weeks(week_start), day_id date not null,
 profile_id uuid references public.public_profiles(id), seed integer not null check(seed between 1 and 100),
 points integer not null default 0, greens integer not null default 0, level integer not null,
 reconstructed boolean not null default false,
 primary key(week_start,day_id,profile_id), check(day_id between week_start and week_start+3)
);
create table public.arena_week_seeds (
 week_start date references public.arena_weeks(week_start), profile_id uuid references public.public_profiles(id),
 seed integer not null check(seed between 1 and 8), points integer not null, greens integer not null,
 primary key(week_start,seed), unique(week_start,profile_id)
);
create table public.arena_week_matches (
 week_start date references public.arena_weeks(week_start), match_key text not null,
 day_id date not null, home_id uuid references public.public_profiles(id), away_id uuid references public.public_profiles(id),
 home_seed integer, away_seed integer, home_points integer not null default 0, away_points integer not null default 0,
 home_greens integer not null default 0, away_greens integer not null default 0,
 winner_id uuid references public.public_profiles(id), status text not null default 'pending' check(status in ('pending','open','finished')),
 primary key(week_start,match_key), check(match_key in ('Q1','Q2','Q3','Q4','S1','S2','F'))
);
create table public.arena_week_titles (
 award_key text primary key, week_start date unique references public.arena_weeks(week_start),
 profile_id uuid not null references public.public_profiles(id), source text not null check(source in ('weekly','admin_preview')),
 awarded_at timestamptz not null default now()
);
alter table public.arena_weeks enable row level security;
alter table public.arena_week_scores enable row level security;
alter table public.arena_week_seeds enable row level security;
alter table public.arena_week_matches enable row level security;
alter table public.arena_week_titles enable row level security;
revoke all on public.arena_weeks,public.arena_week_scores,public.arena_week_seeds,public.arena_week_matches,public.arena_week_titles from public,anon,authenticated;

create or replace function public.ensure_arena_round(p_day date) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 perform pg_advisory_xact_lock(hashtext('arena-round'));
 if p_day<>public.battle_today() or extract(isodow from p_day)>4 then return; end if;
 if exists(select 1 from public.arena_rounds where day_id=p_day) then return; end if;
 insert into public.arena_rounds(day_id) values(p_day);
 insert into public.arena_entries(day_id,profile_id,seed,qualifying_points,level)
 select p_day,id,row_number() over(order by rank_points desc,player_id),rank_points,level
 from public.public_profiles order by rank_points desc,player_id limit 100;
end;$$;

create or replace function public.refresh_weekly_arena() returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare d date:=public.battle_today(); w date; m record; finished boolean; hp integer; ap integer; hg integer; ag integer; champ uuid;
begin
 perform pg_advisory_xact_lock(hashtext('arena-round'));
 insert into public.arena_weeks(week_start) values(date_trunc('week',d)::date) on conflict do nothing;
 -- Also finish an older bracket if a result was confirmed after its scheduled day.
 for w in select week_start from public.arena_weeks where status<>'finished' order by week_start loop
  if (select status from public.arena_weeks where week_start=w)='qualifying' then
   insert into public.arena_week_scores(week_start,day_id,profile_id,seed,points,greens,level)
   select w,e.day_id,e.profile_id,e.seed,e.points,e.greens,e.level from public.arena_entries e
   where e.day_id between w and w+3 on conflict do nothing;
   update public.arena_week_scores s set points=t.points,greens=t.greens,level=t.level from (
    select a.day_id,a.profile_id,coalesce(sum((o.value->>'rankPoints')::int) filter(where k.status='green'),0)::int points,
    count(*) filter(where k.status='green')::int greens,p.level
    from public.arena_week_scores a join public.public_profiles p on p.id=a.profile_id
    left join public.picks k on k.profile_id=a.profile_id and k.prediction_day=a.day_id
    left join public.predictions g on g.day_id=k.prediction_day and g.slot=k.slot
    left join lateral jsonb_array_elements(g.options)o(value) on o.value->>'id'=k.option_id
    where a.week_start=w group by a.day_id,a.profile_id,p.level
   )t where s.week_start=w and s.day_id=t.day_id and s.profile_id=t.profile_id;
   finished:=d>=w+4 and (select count(distinct day_id) from public.predictions where day_id between w and w+3)=4
    and not exists(select 1 from generate_series(w,w+3,'1 day') a where (select count(*) from public.predictions where day_id=a::date)<>10)
    and not exists(select 1 from public.predictions where day_id between w and w+3 and status<>'settled');
   if finished and (select count(distinct profile_id) from public.arena_week_scores where week_start=w)>=8 then
    insert into public.arena_week_seeds(week_start,profile_id,seed,points,greens)
    select w,profile_id,row_number() over(order by sum(points) desc,sum(greens) desc,max(s.level) desc,p.player_id),sum(points),sum(greens)
    from public.arena_week_scores s join public.public_profiles p on p.id=s.profile_id where week_start=w
    group by profile_id,p.player_id order by sum(points) desc,sum(greens) desc,max(s.level) desc,p.player_id limit 8;
    insert into public.arena_week_matches(week_start,match_key,day_id,home_id,away_id,home_seed,away_seed,status)
    select w,q.key,w+4,h.profile_id,a.profile_id,q.h,q.a,'open' from (values('Q1',1,8),('Q2',4,5),('Q3',2,7),('Q4',3,6))q(key,h,a)
    join public.arena_week_seeds h on h.week_start=w and h.seed=q.h join public.arena_week_seeds a on a.week_start=w and a.seed=q.a;
    insert into public.arena_week_matches(week_start,match_key,day_id) values(w,'S1',w+5),(w,'S2',w+5),(w,'F',w+6);
    update public.arena_weeks set status='knockout',frozen_at=now() where week_start=w;
   end if;
  end if;
  for m in select * from public.arena_week_matches where week_start=w and status<>'finished'
   order by day_id,match_key loop
   if m.match_key in ('S1','S2','F') then
    select h.winner_id,a.winner_id,case when h.winner_id=h.home_id then h.home_seed else h.away_seed end,
     case when a.winner_id=a.home_id then a.home_seed else a.away_seed end
    into m.home_id,m.away_id,m.home_seed,m.away_seed from public.arena_week_matches h join public.arena_week_matches a on a.week_start=h.week_start
    where h.week_start=w and h.match_key=case m.match_key when 'S1' then 'Q1' when 'S2' then 'Q3' else 'S1' end
    and a.match_key=case m.match_key when 'S1' then 'Q2' when 'S2' then 'Q4' else 'S2' end and h.status='finished' and a.status='finished';
    if m.home_id is null or m.away_id is null then continue; end if;
    update public.arena_week_matches set home_id=m.home_id,away_id=m.away_id,home_seed=m.home_seed,away_seed=m.away_seed,status='open' where week_start=w and match_key=m.match_key;
   end if;
   select coalesce(sum((o.value->>'rankPoints')::int) filter(where k.profile_id=m.home_id and k.status='green'),0),
    coalesce(sum((o.value->>'rankPoints')::int) filter(where k.profile_id=m.away_id and k.status='green'),0),
    count(*) filter(where k.profile_id=m.home_id and k.status='green'),count(*) filter(where k.profile_id=m.away_id and k.status='green') into hp,ap,hg,ag
   from public.picks k join public.predictions g on g.day_id=k.prediction_day and g.slot=k.slot
   join lateral jsonb_array_elements(g.options)o(value) on o.value->>'id'=k.option_id
   where k.prediction_day=m.day_id and k.profile_id in (m.home_id,m.away_id);
   finished:=d>=m.day_id and (select count(*) from public.predictions where day_id=m.day_id)=10
    and not exists(select 1 from public.predictions where day_id=m.day_id and status<>'settled');
   champ:=case when hp>ap or (hp=ap and (hg>ag or (hg=ag and m.home_seed<m.away_seed))) then m.home_id else m.away_id end;
   update public.arena_week_matches set home_points=hp,away_points=ap,home_greens=hg,away_greens=ag,
    status=case when finished then 'finished' else 'open' end,winner_id=case when finished then champ else null end where week_start=w and match_key=m.match_key;
   if finished and m.match_key='F' then
    insert into public.arena_week_titles(award_key,week_start,profile_id,source) values('week:'||w,w,champ,'weekly') on conflict do nothing;
    update public.arena_weeks set status='finished',winner_id=champ,finished_at=now() where week_start=w;
   end if;
  end loop;
 end loop;
end;$$;

-- Refresh from the same result/pick triggers as the traditional Arena.
do $$ declare definition text; begin
 definition:=pg_get_functiondef('public.refresh_arena_round(date)'::regprocedure);
 definition:=replace(definition,'if exists(select 1 from public.predictions where day_id=p_day) and not exists','if (select count(*) from public.predictions where day_id=p_day)=10 and not exists');
 definition:=replace(definition,'then return; end if;','then perform public.refresh_weekly_arena(); return; end if;');
 definition:=replace(definition,E'\nend;',E'\n perform public.refresh_weekly_arena();\nend;');
 execute definition;
 definition:=pg_get_functiondef('public.arena_pick_changed()'::regprocedure);
 definition:=replace(definition,'return null;','perform public.refresh_weekly_arena(); return null;');execute definition;
 definition:=pg_get_functiondef('public.get_profile_overview_meta(uuid)'::regprocedure);
 definition:=replace(definition,'''arenaWins'',p.arena_wins','''arenaWins'',p.arena_wins,''arenaChampionships'',(select count(*) from public.arena_week_titles c where c.profile_id=p.id)');execute definition;
end;$$;

-- The first expanded week uses actual picks, never invented historical rankings.
insert into public.arena_weeks(week_start) values('2026-10-05');
insert into public.arena_week_scores(week_start,day_id,profile_id,seed,level,reconstructed)
select '2026-10-05',d::date,p.id,p.seed,p.level,true from generate_series('2026-10-05'::date,'2026-10-07'::date,'1 day')d
cross join (select id,level,created_at,row_number() over(order by rank_points desc,player_id)seed from public.public_profiles order by rank_points desc,player_id limit 100)p
where timezone('America/Sao_Paulo',p.created_at)::date<=d::date;
-- Expand today's existing round once, preserving all original seeds and picks.
insert into public.arena_entries(day_id,profile_id,seed,qualifying_points,level)
select public.battle_today(),p.id,coalesce((select max(seed) from public.arena_entries where day_id=public.battle_today()),0)+row_number() over(order by p.rank_points desc,p.player_id),p.rank_points,p.level
from public.public_profiles p where exists(select 1 from public.arena_rounds where day_id=public.battle_today() and status='open')
and not exists(select 1 from public.arena_entries e where e.day_id=public.battle_today() and e.profile_id=p.id)
order by p.rank_points desc,p.player_id limit greatest(0,100-(select count(*) from public.arena_entries where day_id=public.battle_today()));

create or replace function public.get_arena() returns jsonb
language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare d date:=public.battle_today(); w date:=date_trunc('week',d)::date; payload jsonb; standings jsonb;
begin
 if auth.uid() is null then raise exception 'Entre para visualizar a Arena.'; end if;
 perform public.ensure_arena_round(d); perform public.refresh_arena_round(d);
 select coalesce(jsonb_agg(public.get_public_profile(profile_id)||jsonb_build_object('position',position,'points',points,'greens',greens,'days',days) order by position),'[]') into standings from (
  select s.profile_id,sum(s.points)::int points,sum(s.greens)::int greens,
   jsonb_object_agg(s.day_id,jsonb_build_object('points',s.points,'greens',s.greens))days,
   row_number() over(order by sum(s.points) desc,sum(s.greens) desc,max(s.level) desc,p.player_id)position
  from public.arena_week_scores s join public.public_profiles p on p.id=s.profile_id where week_start=w group by s.profile_id,p.player_id
 )r;
 select jsonb_build_object('dayId',d,'status',coalesce((select status from public.arena_rounds where day_id=d),'open'),
 'winnerId',(select winner_id from public.arena_rounds where day_id=d),'qualified',exists(select 1 from public.arena_entries where day_id=d and profile_id=public.own_profile_id()),
 'settled',(select count(*) from public.predictions where day_id=d and status='settled'),'total',(select count(*) from public.predictions where day_id=d),
 'king',(select public.get_public_profile(c.profile_id)||jsonb_build_object('wonOn',c.won_on) from public.arena_crown c),
 'players',(select coalesce(jsonb_agg(public.get_public_profile(e.profile_id)||jsonb_build_object('points',e.points,'greens',e.greens,'seed',e.seed,'qualifyingPoints',e.qualifying_points) order by points desc,greens desc,e.level desc,seed),'[]') from public.arena_entries e where day_id=d),
 'week',jsonb_build_object('startsOn',w,'status',s.status,'winner',public.get_public_profile(s.winner_id),'standings',standings,
 'reconstructed',exists(select 1 from public.arena_week_scores where week_start=w and reconstructed),
 'days',(select jsonb_agg(jsonb_build_object('dayId',x.arena_day,'status',case when x.arena_day>d then 'upcoming' when (select count(*) from public.predictions where day_id=x.arena_day)=10 and not exists(select 1 from public.predictions where day_id=x.arena_day and status<>'settled') then 'finished' else 'open' end,
 'winner',(select public.get_public_profile(a.profile_id)||jsonb_build_object('points',a.points,'greens',a.greens) from public.arena_week_scores a join public.public_profiles p on p.id=a.profile_id where a.week_start=w and a.day_id=x.arena_day order by a.points desc,a.greens desc,a.level desc,a.seed,p.player_id limit 1)) order by x.arena_day) from (select generate_series(w,w+3,'1 day')::date as arena_day)x),
 'seeds',(select coalesce(jsonb_agg(public.get_public_profile(profile_id)||jsonb_build_object('seed',seed,'points',points,'greens',greens) order by seed),'[]') from public.arena_week_seeds where week_start=w),
 'matches',(select coalesce(jsonb_agg(jsonb_build_object('key',match_key,'dayId',day_id,'status',status,'home',public.get_public_profile(home_id),'away',public.get_public_profile(away_id),'homeSeed',home_seed,'awaySeed',away_seed,'homePoints',home_points,'awayPoints',away_points,'winnerId',winner_id) order by day_id,match_key),'[]') from public.arena_week_matches where week_start=w))) into payload from public.arena_weeks s where week_start=w;
 return payload;
end;$$;
revoke all on function public.refresh_weekly_arena() from public,anon,authenticated;
select public.refresh_arena_round(public.battle_today());
select cron.schedule('arena-weekly-refresh','* * * * *','select public.refresh_weekly_arena();');
commit;




