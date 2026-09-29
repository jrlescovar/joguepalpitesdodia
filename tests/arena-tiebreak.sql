begin;
do $$
declare d date:=date '1900-01-01'; a uuid; b uuid;
begin
 select id into a from public.public_profiles order by player_id limit 1;
 select id into b from public.public_profiles order by player_id offset 1 limit 1;
 insert into public.arena_rounds(day_id) values(d);
 insert into public.arena_entries(day_id,profile_id,seed,qualifying_points,points,greens,level) values(d,a,1,0,50,3,10),(d,b,2,0,50,3,20);
 if public.arena_winner(d)<>b then raise exception 'Level tiebreak failed'; end if;
 update public.arena_entries set greens=4 where day_id=d and profile_id=a;
 if public.arena_winner(d)<>a then raise exception 'Greens priority failed'; end if;
 update public.arena_entries set points=51 where day_id=d and profile_id=b;
 if public.arena_winner(d)<>b then raise exception 'Points priority failed'; end if;
 update public.arena_entries set points=50,greens=3,level=20 where day_id=d;
 if public.arena_winner(d)<>a then raise exception 'Final stable tiebreak failed'; end if;
end;$$;
rollback;
select jsonb_build_object('arena_tiebreak_passed',true);
