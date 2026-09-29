begin;
do $$
declare winner uuid;d date:=date '1900-01-02'; before_count integer;meta jsonb;
begin
 select id,arena_wins into winner,before_count from public.public_profiles order by player_id limit 1;
 insert into public.arena_rounds(day_id) values(d);
 update public.arena_rounds set status='finished',winner_id=winner where day_id=d;
 if (select arena_wins from public.public_profiles where id=winner)<>before_count+1 then raise exception 'First arena win not recorded'; end if;
 update public.arena_rounds set settled_at=now() where day_id=d;
 if (select arena_wins from public.public_profiles where id=winner)<>before_count+1 then raise exception 'Win double counted'; end if;
 meta:=public.get_profile_overview_meta(winner);
 if (meta->>'arenaWins')::integer<>before_count+1 then raise exception 'Profile medal count stale'; end if;
 begin
  update public.arena_rounds set winner_id=(select id from public.public_profiles where id<>winner order by player_id limit 1) where day_id=d;
  raise exception 'Finished champion edited';
 exception when others then if sqlerrm='Finished champion edited' then raise; end if;end;
end;$$;
rollback;
select jsonb_build_object('arena_medal_tests_passed',true);
