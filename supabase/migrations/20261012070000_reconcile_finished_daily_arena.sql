begin;

-- Reconcile the final podium against its durable award ledger. Only the
-- difference is credited/debited; repeated refreshes cannot award it twice.
create or replace function public.grant_arena_rank_awards(p_day date) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 perform pg_advisory_xact_lock(hashtext('arena-rank-awards-'||p_day::text));
 if not exists(select 1 from public.arena_rounds where day_id=p_day and status='finished') then return; end if;
 if not exists(
  with ranked as (
   select profile_id,row_number() over(order by points desc,greens desc,level desc,seed)::int place
   from public.arena_entries where day_id=p_day
  ), expected as (
   select profile_id,place,case place when 1 then 30 when 2 then 20 else 10 end rank_points
   from ranked where place<=3
  )
  select 1 from expected e full join (select * from public.arena_rank_awards where day_id=p_day)a using(profile_id)
  where e.place is distinct from a.place or e.rank_points is distinct from a.rank_points
 ) then return; end if;
 with ranked as (
  select profile_id,row_number() over(order by points desc,greens desc,level desc,seed)::int place
  from public.arena_entries where day_id=p_day
 ), expected as (
  select profile_id,place,case place when 1 then 30 when 2 then 20 else 10 end rank_points
  from ranked where place<=3
 ), deltas as (
  select coalesce(e.profile_id,a.profile_id) profile_id,
   coalesce(e.rank_points,0)-coalesce(a.rank_points,0) amount
  from expected e full join (select * from public.arena_rank_awards where day_id=p_day)a using(profile_id)
 )
 update public.public_profiles p set rank_points=greatest(0,p.rank_points+d.amount),updated_at=now()
 from deltas d where p.id=d.profile_id and d.amount<>0;

 -- Delete all obsolete places together so the unique place/profile keys can
 -- safely swap. Retain the original timestamp for unchanged ledger rows.
 with ranked as (
  select profile_id,row_number() over(order by points desc,greens desc,level desc,seed)::int place
  from public.arena_entries where day_id=p_day
 ), expected as materialized (
  select r.profile_id,r.place,case r.place when 1 then 30 when 2 then 20 else 10 end rank_points,
   coalesce(a.awarded_at,now()) awarded_at
  from ranked r left join public.arena_rank_awards a
   on a.day_id=p_day and a.profile_id=r.profile_id and a.place=r.place
  where r.place<=3
 ), removed as (
  delete from public.arena_rank_awards where day_id=p_day returning profile_id
 )
 insert into public.arena_rank_awards(day_id,profile_id,place,rank_points,awarded_at)
 select p_day,profile_id,place,rank_points,awarded_at from expected
 cross join (select count(*) from removed) deletion_barrier;
end;
$$;

-- A finished winner can change only to the winner calculated from the
-- corrected table. Reopening a round and arbitrary winner edits stay blocked.
create or replace function public.record_arena_win() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if old.status='finished' then
  if new.status<>old.status then raise exception 'Uma Arena encerrada não pode ser reaberta.'; end if;
  if new.winner_id is distinct from old.winner_id then
   if new.winner_id is null or new.winner_id is distinct from public.arena_winner(new.day_id)
    or (select count(*) from public.predictions where day_id=new.day_id)<>10
    or exists(select 1 from public.predictions where day_id=new.day_id and status<>'settled') then
    raise exception 'O campeão deve corresponder aos resultados confirmados da Arena.';
   end if;
   update public.public_profiles set arena_wins=greatest(0,arena_wins-1) where id=old.winner_id;
   update public.public_profiles set arena_wins=arena_wins+1 where id=new.winner_id;
  end if;
 elsif new.status='finished' and new.winner_id is not null then
  update public.public_profiles set arena_wins=arena_wins+1 where id=new.winner_id;
 end if;
 return new;
end;
$$;

create or replace function public.refresh_arena_round(p_day date) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare champion uuid; round_status text;
begin
 perform pg_advisory_xact_lock(hashtext('arena-round'));
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
$$;

-- Statement transition tables refresh only affected dates, including finished
-- rounds; XP-only updates and unrelated history do not trigger a full rescan.
create function public.arena_picks_inserted() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare d date;
begin
 for d in select distinct prediction_day from arena_new_picks order by prediction_day loop
  perform public.refresh_arena_round(d);
 end loop;
 return null;
end;
$$;
create function public.arena_picks_updated() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare d date;
begin
 for d in
  select distinct coalesce(n.prediction_day,o.prediction_day) day_id
  from arena_new_picks n full join arena_old_picks o using(profile_id,prediction_day,slot)
  where n.option_id is distinct from o.option_id or n.status is distinct from o.status
  order by day_id
 loop
  perform public.refresh_arena_round(d);
 end loop;
 return null;
end;
$$;
drop trigger arena_pick_changed on public.picks;
drop function public.arena_pick_changed();
create trigger arena_picks_inserted after insert on public.picks
 referencing new table as arena_new_picks for each statement execute function public.arena_picks_inserted();
create trigger arena_picks_updated after update on public.picks
 referencing old table as arena_old_picks new table as arena_new_picks
 for each statement execute function public.arena_picks_updated();
drop trigger arena_prediction_changed on public.predictions;
create trigger arena_prediction_changed after insert or update of status,options,winning_option_id
 on public.predictions for each row execute function public.arena_prediction_changed();

revoke all on function public.grant_arena_rank_awards(date),public.record_arena_win(),
 public.refresh_arena_round(date),public.arena_picks_inserted(),public.arena_picks_updated()
 from public,anon,authenticated,service_role;
notify pgrst,'reload schema';
commit;
