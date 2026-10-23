-- Execute with migration inside BEGIN/ROLLBACK; no production data persists.
create temporary table real_arena_profiles as select id,to_jsonb(p) data from public.public_profiles p;
create temporary table real_arena_crown as select to_jsonb(c) data from public.arena_crown c;
create temporary table real_arena_awards as select day_id,profile_id,to_jsonb(a) data from public.arena_rank_awards a;
create temporary table real_arena_rounds as select day_id,to_jsonb(r) data from public.arena_rounds r;
insert into public.public_profiles(id,player_id,username,avatar_color,rank_points,level)
values('aaaaaa70-0000-4000-8000-000000000001',9907001,'arenafixqa1','#3b82f6',200,2),
 ('aaaaaa70-0000-4000-8000-000000000002',9907002,'arenafixqa2','#3b82f6',200,3),
 ('aaaaaa70-0000-4000-8000-000000000003',9907003,'arenafixqa3','#3b82f6',200,4),
 ('aaaaaa70-0000-4000-8000-000000000004',9907004,'arenafixqa4','#3b82f6',200,5);
insert into public.arena_rounds(day_id) values('2000-01-03');
insert into public.arena_entries(day_id,profile_id,seed,qualifying_points,level)
select '2000-01-03',id,player_id-9907000,200,level from public.public_profiles where player_id between 9907001 and 9907004;
insert into public.predictions(day_id,slot,title,options,closes_at,status)
select '2000-01-03',s::smallint,'Arena correction QA','[{"id":"home","label":"Casa","rankPoints":50},{"id":"away","label":"Fora","rankPoints":30}]', '2000-01-03T16:00:00-03:00','open' from generate_series(0,9)s;
insert into public.picks(profile_id,prediction_day,slot,option_id,status)
select id,'2000-01-03',s::smallint,case when player_id=9907001 or (player_id=9907002 and s=0) or (player_id=9907003 and s=1) then 'home' else 'away' end,
case when player_id=9907001 or (player_id=9907002 and s=0) or (player_id=9907003 and s=1) then 'green' else 'red' end
from public.public_profiles cross join generate_series(0,1)s where player_id between 9907001 and 9907004;
update public.predictions set status='settled',winning_option_id='home',settled_at=now() where day_id='2000-01-03';
create temporary table original_arena_settlement as select settled_at from public.arena_rounds where day_id='2000-01-03';
do $$
begin
 if not exists(select 1 from public.arena_rounds where day_id='2000-01-03' and status='finished' and winner_id='aaaaaa70-0000-4000-8000-000000000001') then raise exception 'Initial winner wrong'; end if;
 if (select sum(rank_points) from public.public_profiles where player_id between 9907001 and 9907004)<>860 then raise exception 'Initial podium bonuses wrong'; end if;
end;
$$;
-- A correction changes the finished champion through the existing pick trigger.
update public.picks set option_id='home',status='green'
 where profile_id='aaaaaa70-0000-4000-8000-000000000002' and prediction_day='2000-01-03' and slot=1;
do $$
begin
 if not exists(select 1 from public.arena_rounds where day_id='2000-01-03' and winner_id='aaaaaa70-0000-4000-8000-000000000002') then raise exception 'Finished champion did not update'; end if;
 if not exists(select 1 from public.public_profiles where player_id=9907001 and arena_wins=0 and rank_points=220) or not exists(select 1 from public.public_profiles where player_id=9907002 and arena_wins=1 and rank_points=230) then raise exception 'Medal/award transfer incorrect'; end if;
end;
$$;
-- Bulk corrections must see the entire statement, including a new podium entrant.
update public.picks set option_id='home',status='green' where prediction_day='2000-01-03'
 and profile_id in ('aaaaaa70-0000-4000-8000-000000000003','aaaaaa70-0000-4000-8000-000000000004');
do $$
begin
 if not exists(select 1 from public.arena_rounds where day_id='2000-01-03' and winner_id='aaaaaa70-0000-4000-8000-000000000004') then raise exception 'Bulk correction winner wrong'; end if;
 if not exists(select 1 from public.public_profiles where player_id=9907001 and arena_wins=0 and rank_points=200) or not exists(select 1 from public.public_profiles where player_id=9907004 and arena_wins=1 and rank_points=230) then raise exception 'Removed/new podium rewards wrong'; end if;
 if (select sum(rank_points) from public.public_profiles where player_id between 9907001 and 9907004)<>860 then raise exception 'Bulk update duplicated awards'; end if;
end;
$$;
-- Point edits on a finished prediction also refresh the daily table.
update public.predictions set options='[{"id":"home","label":"Casa","rankPoints":100},{"id":"away","label":"Fora","rankPoints":30}]' where day_id='2000-01-03' and slot=0;
do $$
begin
 if exists(select 1 from public.arena_entries where day_id='2000-01-03' and (points<>150 or greens<>2)) then raise exception 'Changed point values not reflected'; end if;
 -- Unrelated leveling after closing must not change the frozen tiebreak.
 update public.public_profiles set level=99 where player_id=9907001;
 perform public.refresh_arena_round('2000-01-03');
 if not exists(select 1 from public.arena_entries where day_id='2000-01-03' and profile_id='aaaaaa70-0000-4000-8000-000000000001' and level=2) then raise exception 'Finished level snapshot changed'; end if;
 begin
  update public.arena_rounds set winner_id='aaaaaa70-0000-4000-8000-000000000001' where day_id='2000-01-03';
  raise exception 'Arbitrary winner edit allowed';
 exception when others then if sqlerrm='Arbitrary winner edit allowed' then raise; end if; end;
 begin
  update public.arena_rounds set status='open' where day_id='2000-01-03';
  raise exception 'Finished round reopened';
 exception when others then if sqlerrm='Finished round reopened' then raise; end if; end;
 if (select settled_at from public.arena_rounds where day_id='2000-01-03') is distinct from (select settled_at from original_arena_settlement) then raise exception 'Original settlement time changed'; end if;
 if (select count(*) from public.arena_rank_awards where day_id='2000-01-03')<>3 then raise exception 'Award ledger wrong'; end if;
end;
$$;
create temporary table arena_fix_profiles_after as select id,to_jsonb(p) data from public.public_profiles p;
create temporary table arena_fix_awards_after as select day_id,profile_id,to_jsonb(a) data from public.arena_rank_awards a;
select public.refresh_arena_round('2000-01-03');
select public.grant_arena_rank_awards('2000-01-03');
do $$
begin
 if exists(select 1 from arena_fix_profiles_after s join public.public_profiles p using(id) where s.data<>to_jsonb(p)) or exists(select 1 from arena_fix_awards_after s join public.arena_rank_awards a using(day_id,profile_id) where s.data<>to_jsonb(a)) then raise exception 'Replay changed profiles or ledger'; end if;
 if exists(select 1 from real_arena_profiles s join public.public_profiles p using(id) where s.data<>to_jsonb(p)) or exists(select 1 from real_arena_awards s join public.arena_rank_awards a using(day_id,profile_id) where s.data<>to_jsonb(a)) or exists(select 1 from real_arena_rounds s join public.arena_rounds r using(day_id) where s.data<>to_jsonb(r)) then raise exception 'Unrelated real arena changed'; end if;
 if exists(select 1 from real_arena_crown s full join public.arena_crown c on true where s.data is distinct from to_jsonb(c)) then raise exception 'An older correction replaced the current crown'; end if;
 if has_function_privilege('authenticated','public.refresh_arena_round(date)','EXECUTE') or has_function_privilege('anon','public.grant_arena_rank_awards(date)','EXECUTE') then raise exception 'Private reconciliation exposed'; end if;
end;
$$;
select 'PASS: finished pick and point corrections; bulk statements; winner/medals; podium award swaps; no duplicate credit; frozen tiebreak/time; older crown protected; permissions; real data unchanged' as result;
