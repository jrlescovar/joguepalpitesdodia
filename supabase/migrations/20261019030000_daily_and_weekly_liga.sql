begin;
alter table public.arena_week_scores drop constraint arena_week_scores_check;
alter table public.arena_week_scores add constraint arena_week_scores_check check(day_id between week_start and week_start+6);

-- The completed championships before 19 October remain historical records.
create or replace function public.refresh_weekly_arena() returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare d date:=public.battle_today(); w date; champ uuid; complete boolean;
begin
 perform pg_advisory_xact_lock(hashtext('arena-round'));
 insert into public.arena_weeks(week_start) values(date_trunc('week',d)::date) on conflict do nothing;
 for w in select week_start from public.arena_weeks where week_start>=date '2026-10-19' and week_start<=d order by week_start loop
  insert into public.arena_week_scores(week_start,day_id,profile_id,seed,points,greens,level)
  select w,e.day_id,e.profile_id,e.seed,e.points,e.greens,e.level from public.arena_entries e
  where e.day_id between w and w+6 on conflict do nothing;
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
end;$$;
revoke all on function public.refresh_weekly_arena() from public,anon,authenticated;

create or replace function public.get_liga_week_history() returns jsonb
language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Entre para visualizar a Liga.'; end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('startsOn',t.week_start,'endsOn',t.week_start+6,'winner',public.get_public_profile(t.profile_id)) order by t.week_start desc),'[]'::jsonb)
 from public.arena_week_titles t where t.source='weekly' and t.week_start is not null);
end;$$;
revoke all on function public.get_liga_week_history() from public,anon;
grant execute on function public.get_liga_week_history() to authenticated;
CREATE OR REPLACE FUNCTION public.get_arena()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare d date:=public.battle_today(); w date:=date_trunc('week',d)::date; payload jsonb; standings jsonb;
begin
 if auth.uid() is null then raise exception 'Entre para visualizar a Liga.'; end if;
 perform public.ensure_arena_round(d); perform public.refresh_arena_round(d);
 select coalesce(jsonb_agg((public.get_public_profile(profile_id)||public.battle_rank_meta(profile_id))||jsonb_build_object('position',position,'points',points,'greens',greens,'days',days) order by position),'[]') into standings from (
  select s.profile_id,sum(s.points)::int points,sum(s.greens)::int greens,
   jsonb_object_agg(s.day_id,jsonb_build_object('points',s.points,'greens',s.greens))days,
   row_number() over(order by sum(s.points) desc,sum(s.greens) desc,max(s.level) desc,p.player_id)position
  from public.arena_week_scores s join public.public_profiles p on p.id=s.profile_id where week_start=w group by s.profile_id,p.player_id
 )r;
 select jsonb_build_object('dayId',d,'status',coalesce((select status from public.arena_rounds where day_id=d),'open'),
 'winnerId',(select winner_id from public.arena_rounds where day_id=d),'qualified',exists(select 1 from public.arena_entries where day_id=d and profile_id=public.own_profile_id()),
 'settled',(select count(*) from public.predictions where day_id=d and status='settled'),'total',(select count(*) from public.predictions where day_id=d),
 'king',(select public.get_public_profile(c.profile_id)||jsonb_build_object('wonOn',c.won_on) from public.arena_crown c),
 'players',(select coalesce(jsonb_agg(public.get_public_profile(e.profile_id)||jsonb_build_object('points',e.points,'greens',e.greens,'seed',e.seed,'qualifyingPoints',e.qualifying_points) order by points desc,case when e.day_id>=date '2026-10-17' then e.seed end,greens desc,e.level desc,seed),'[]') from public.arena_entries e where day_id=d),
 'week',jsonb_build_object('startsOn',w,'status',s.status,'winner',public.get_public_profile(s.winner_id),'standings',standings,
 'reconstructed',exists(select 1 from public.arena_week_scores where week_start=w and reconstructed),
 'days',(select jsonb_agg(jsonb_build_object('dayId',x.arena_day,'status',case when x.arena_day>d then 'upcoming' when (select count(*) from public.predictions where day_id=x.arena_day)=10 and not exists(select 1 from public.predictions where day_id=x.arena_day and status<>'settled') then 'finished' else 'open' end,
 'winner',(select public.get_public_profile(a.profile_id)||jsonb_build_object('points',a.points,'greens',a.greens) from public.arena_week_scores a join public.public_profiles p on p.id=a.profile_id where a.week_start=w and a.day_id=x.arena_day order by a.points desc,case when a.day_id>=date '2026-10-17' then a.seed end,a.greens desc,a.level desc,a.seed,p.player_id limit 1)) order by x.arena_day) from (select generate_series(w,w+6,'1 day')::date as arena_day)x),
 'seeds',(select coalesce(jsonb_agg((public.get_public_profile(profile_id)||public.battle_rank_meta(profile_id))||jsonb_build_object('seed',seed,'points',points,'greens',greens) order by seed),'[]') from public.arena_week_seeds where week_start=w),
 'matches',(select coalesce(jsonb_agg(jsonb_build_object('key',match_key,'dayId',day_id,'status',status,'home',(public.get_public_profile(home_id)||public.battle_rank_meta(home_id)),'away',(public.get_public_profile(away_id)||public.battle_rank_meta(away_id)),'homeSeed',home_seed,'awaySeed',away_seed,'homePoints',home_points,'awayPoints',away_points,'winnerId',winner_id) order by day_id,match_key),'[]') from public.arena_week_matches where week_start=w))) into payload from public.arena_weeks s where week_start=w;
 return payload;
end;$function$
;
select public.refresh_weekly_arena();
notify pgrst,'reload schema';
commit;
