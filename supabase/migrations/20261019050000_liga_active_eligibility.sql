begin;
select pg_advisory_xact_lock(hashtext('arena-round'));
alter table public.arena_entries drop constraint arena_entries_seed_check;
alter table public.arena_entries add constraint arena_entries_seed_check check(seed>=1);
alter table public.arena_week_scores drop constraint arena_week_scores_seed_check;
alter table public.arena_week_scores add constraint arena_week_scores_seed_check check(seed>=1);

create table public.liga_week_participants (
 week_start date not null references public.arena_weeks(week_start),
 profile_id uuid not null references public.public_profiles(id),
 seed integer not null check(seed>=1),
 joined_at timestamptz not null default now(),
 primary key(week_start,profile_id),unique(week_start,seed)
);
alter table public.liga_week_participants enable row level security;
revoke all on public.liga_week_participants from public,anon,authenticated;

create or replace function public.ensure_arena_round(p_day date) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare offset_seed integer;
begin
 perform pg_advisory_xact_lock(hashtext('arena-round'));
 if p_day<>public.battle_today() then return; end if;
 insert into public.arena_rounds(day_id) values(p_day) on conflict do nothing;
 select coalesce(max(seed),0) into offset_seed from public.arena_entries where day_id=p_day;
 insert into public.arena_entries(day_id,profile_id,seed,qualifying_points,level)
 select p_day,p.id,offset_seed+row_number() over(order by p.rank_points desc,p.player_id),p.rank_points,p.level
 from public.public_profiles p
 where exists(select 1 from public.picks k where k.profile_id=p.id and k.prediction_day between p_day-1 and p_day)
 and not exists(select 1 from public.arena_entries e where e.day_id=p_day and e.profile_id=p.id);
end;$$;
revoke all on function public.ensure_arena_round(date) from public,anon,authenticated;

-- Reconcile only the new phase; preserve all completed daily and weekly history.
delete from public.arena_week_scores where week_start=date '2026-10-19';
delete from public.arena_entries e where e.day_id=public.battle_today() and e.day_id>=date '2026-10-19'
 and not exists(select 1 from public.picks k where k.profile_id=e.profile_id and k.prediction_day between e.day_id-1 and e.day_id);
CREATE OR REPLACE FUNCTION public.refresh_weekly_arena()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$

declare d date:=public.battle_today(); w date; champ uuid; complete boolean;

begin

 perform pg_advisory_xact_lock(hashtext('arena-round'));

 perform public.ensure_arena_round(d);
 insert into public.arena_weeks(week_start) values(date_trunc('week',d)::date) on conflict do nothing;

 for w in select week_start from public.arena_weeks where week_start>=date '2026-10-19' and week_start<=d order by week_start loop

  -- Only Monday's daily participants can join this week's fixed roster.
  if d=w then
   insert into public.liga_week_participants(week_start,profile_id,seed)
   select w,e.profile_id,e.seed from public.arena_entries e where e.day_id=w on conflict do nothing;
  end if;
  update public.arena_weeks set frozen_at=coalesce(frozen_at,(w+1)::timestamp at time zone 'America/Sao_Paulo') where week_start=w and d>w;
  insert into public.arena_week_scores(week_start,day_id,profile_id,seed,level)
  select w,x.day_id::date,r.profile_id,r.seed,p.level
  from public.liga_week_participants r join public.public_profiles p on p.id=r.profile_id
  cross join generate_series(w,least(d,w+6),'1 day')x(day_id)
  where r.week_start=w on conflict do nothing;
  update public.arena_week_scores s set points=t.points,greens=t.greens,level=t.level from (

   select a.day_id,a.profile_id,coalesce(sum((o.value->>'rankPoints')::int) filter(where k.status='green'),0)::int points,

    count(*) filter(where k.status='green')::int greens,p.level

   from public.arena_week_scores a join public.public_profiles p on p.id=a.profile_id

   left join public.picks k on k.profile_id=a.profile_id and k.prediction_day=a.day_id

   left join public.predictions g on g.day_id=k.prediction_day and g.slot=k.slot

   left join lateral jsonb_array_elements(g.options)o(value) on o.value->>'id'=k.option_id

   where a.week_start=w group by a.day_id,a.profile_id,p.level

  )t where s.week_start=w and s.day_id=t.day_id and s.profile_id=t.profile_id;

  complete:=d>=w+6 and (select count(distinct day_id) from public.predictions where day_id between w and w+6)=7

   and not exists(select 1 from public.predictions where day_id between w and w+6 and status<>'settled');

  if complete then

   select s.profile_id into champ from public.arena_week_scores s join public.public_profiles p on p.id=s.profile_id

   where s.week_start=w group by s.profile_id,p.player_id

   order by sum(s.points) desc,sum(s.greens) desc,max(s.level) desc,p.player_id limit 1;

   if champ is not null then

    insert into public.arena_week_titles(award_key,week_start,profile_id,source) values('week:'||w,w,champ,'weekly')

    on conflict(week_start) do update set profile_id=excluded.profile_id;

    update public.arena_weeks set status='finished',winner_id=champ,finished_at=coalesce(finished_at,now()) where week_start=w;

   end if;

  else

   update public.arena_weeks set status='qualifying',winner_id=null,finished_at=null where week_start=w;

   delete from public.arena_week_titles where week_start=w and source='weekly';

  end if;

 end loop;

end;$function$
;
CREATE OR REPLACE FUNCTION public.refresh_arena_round(p_day date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare champion uuid; round_status text;
begin
 perform pg_advisory_xact_lock(hashtext('arena-round'));
 perform public.ensure_arena_round(p_day);
 select status into round_status from public.arena_rounds where day_id=p_day;
 if round_status is null then perform public.refresh_weekly_arena(); return; end if;
 update public.arena_entries e set points=s.points,greens=s.greens,
  level=case when round_status='open' then p.level else e.level end
 from (
  select a.profile_id,
   coalesce(sum(coalesce((o.value->>'rankPoints')::int,0)) filter(where k.status='green'),0)::int points,
   count(*) filter(where k.status='green')::int greens
  from public.arena_entries a
  left join public.picks k on k.profile_id=a.profile_id and k.prediction_day=a.day_id
  left join public.predictions g on g.day_id=k.prediction_day and g.slot=k.slot
  left join lateral jsonb_array_elements(g.options)o(value) on o.value->>'id'=k.option_id
  where a.day_id=p_day group by a.profile_id
 )s join public.public_profiles p on p.id=s.profile_id
 where e.day_id=p_day and e.profile_id=s.profile_id
  and (e.points is distinct from s.points or e.greens is distinct from s.greens
   or (round_status='open' and e.level is distinct from p.level));
 if (select count(*) from public.predictions where day_id=p_day)=10
  and not exists(select 1 from public.predictions where day_id=p_day and status<>'settled') then
  champion:=public.arena_winner(p_day);
  if champion is not null then
   update public.arena_rounds set status='finished',winner_id=champion,
    settled_at=case when round_status='finished' then settled_at else now() end
   where day_id=p_day and (status<>'finished' or winner_id is distinct from champion);
   insert into public.arena_crown(singleton,profile_id,won_on) values(true,champion,p_day)
   on conflict(singleton) do update set profile_id=excluded.profile_id,won_on=excluded.won_on
   where public.arena_crown.won_on<=excluded.won_on
    and (public.arena_crown.profile_id is distinct from excluded.profile_id or public.arena_crown.won_on is distinct from excluded.won_on);
   perform public.grant_arena_rank_awards(p_day);
  end if;
 end if;
 perform public.refresh_weekly_arena();
end;
$function$
;
select public.ensure_arena_round(public.battle_today());
select public.refresh_arena_round(public.battle_today());
notify pgrst,'reload schema';
commit;
