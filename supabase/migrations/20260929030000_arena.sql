begin;
create table public.arena_rounds(day_id date primary key,status text not null default 'open' check(status in ('open','finished')),winner_id uuid references public.public_profiles(id),settled_at timestamptz);
create table public.arena_entries(day_id date references public.arena_rounds(day_id) on delete cascade,profile_id uuid references public.public_profiles(id),seed integer not null check(seed between 1 and 10),qualifying_points integer not null,points integer not null default 0,greens integer not null default 0,primary key(day_id,profile_id),unique(day_id,seed));
create table public.arena_crown(singleton boolean primary key default true check(singleton),profile_id uuid not null references public.public_profiles(id),won_on date not null);
alter table public.arena_rounds enable row level security;
alter table public.arena_entries enable row level security;
alter table public.arena_crown enable row level security;
create function public.ensure_arena_round(p_day date) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 perform pg_advisory_xact_lock(hashtext('arena-round'));
 if p_day<>public.battle_today() then return; end if;
 if exists(select 1 from public.arena_rounds where day_id=p_day) then return; end if;
 insert into public.arena_rounds(day_id) values(p_day);
 insert into public.arena_entries(day_id,profile_id,seed,qualifying_points)
 select p_day,id,row_number() over(order by rank_points desc,player_id),rank_points from public.public_profiles order by rank_points desc,player_id limit 10;
 -- Only two compact rounds are retained; the crown survives independently.
 delete from public.arena_rounds where day_id<p_day-1 and status='finished';
end;$$;
create function public.refresh_arena_round(p_day date) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare champion uuid;
begin
 perform pg_advisory_xact_lock(hashtext('arena-round'));
 if not exists(select 1 from public.arena_rounds where day_id=p_day and status='open') then return; end if;
 update public.arena_entries e set points=s.points,greens=s.greens from (
 select a.profile_id,coalesce(sum(coalesce((o.value->>'rankPoints')::integer,0)) filter(where k.status='green'),0)::integer points,count(*) filter(where k.status='green')::integer greens
 from public.arena_entries a left join public.picks k on k.profile_id=a.profile_id and k.prediction_day=a.day_id
 left join public.predictions g on g.day_id=k.prediction_day and g.slot=k.slot
 left join lateral jsonb_array_elements(g.options) o(value) on o.value->>'id'=k.option_id
 where a.day_id=p_day group by a.profile_id) s where e.day_id=p_day and e.profile_id=s.profile_id;
 if exists(select 1 from public.predictions where day_id=p_day) and not exists(select 1 from public.predictions where day_id=p_day and status<>'settled') then
 select profile_id into champion from public.arena_entries where day_id=p_day order by points desc,greens desc,seed limit 1;
 if champion is not null then
 update public.arena_rounds set status='finished',winner_id=champion,settled_at=now() where day_id=p_day;
 insert into public.arena_crown(singleton,profile_id,won_on) values(true,champion,p_day) on conflict(singleton) do update set profile_id=excluded.profile_id,won_on=excluded.won_on where public.arena_crown.won_on<=excluded.won_on;
 end if;
 end if;
end;$$;
create function public.arena_prediction_changed() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.day_id=public.battle_today() then perform public.ensure_arena_round(new.day_id); end if;
 perform public.refresh_arena_round(new.day_id);
 return new;
end;$$;
create trigger arena_prediction_changed after insert or update of status on public.predictions for each row execute function public.arena_prediction_changed();
create function public.arena_pick_changed() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare d date;
begin
 for d in select day_id from public.arena_rounds where status='open' loop perform public.refresh_arena_round(d); end loop;
 return null;
end;$$;
create trigger arena_pick_changed after insert or update of status,option_id on public.picks for each statement execute function public.arena_pick_changed();
create function public.get_arena() returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare d date:=public.battle_today(); payload jsonb;
begin
 if auth.uid() is null then raise exception 'Entre para visualizar a Arena.'; end if;
 if not exists(select 1 from public.arena_rounds where day_id=d) then perform public.ensure_arena_round(d); perform public.refresh_arena_round(d); end if;
 select jsonb_build_object('dayId',r.day_id,'status',r.status,'winnerId',r.winner_id,
 'qualified',exists(select 1 from public.arena_entries where day_id=d and profile_id=public.own_profile_id()),
 'settled', (select count(*) from public.predictions where day_id=d and status='settled'),
 'total',(select count(*) from public.predictions where day_id=d),
 'king',(select public.get_public_profile(c.profile_id)||jsonb_build_object('wonOn',c.won_on) from public.arena_crown c),
 'players',(select coalesce(jsonb_agg(public.get_public_profile(e.profile_id)||jsonb_build_object('points',e.points,'greens',e.greens,'seed',e.seed,'qualifyingPoints',e.qualifying_points) order by e.points desc,e.greens desc,e.seed),'[]'::jsonb) from public.arena_entries e where e.day_id=d)) into payload from public.arena_rounds r where r.day_id=d;
 return payload;
end;$$;
create function public.get_arena_king(p_profile_id uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$ select exists(select 1 from public.arena_crown where profile_id=p_profile_id) and auth.uid() is not null; $$;
revoke all on public.arena_rounds,public.arena_entries,public.arena_crown from public,anon,authenticated;
revoke all on function public.ensure_arena_round(date),public.refresh_arena_round(date),public.arena_prediction_changed(),public.arena_pick_changed(),public.get_arena(),public.get_arena_king(uuid) from public,anon,authenticated;
grant execute on function public.get_arena(),public.get_arena_king(uuid) to authenticated;
select public.ensure_arena_round(public.battle_today());
select public.refresh_arena_round(public.battle_today());
select cron.schedule('arena-brasilia-midnight','0 3 * * *',$job$select public.ensure_arena_round(public.battle_today());$job$);
commit;
