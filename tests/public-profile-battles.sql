begin;
update public.daily_battles set result='left',left_points=70,right_points=30,left_rank_delta=15,right_rank_delta=-10 where id=(select id from public.daily_battles where day_id=public.battle_today() and player_right is not null order by id limit 1);
do $$
declare b public.daily_battles; left_view jsonb;right_view jsonb;before_hash text;after_hash text;
begin
 select * into b from public.daily_battles where day_id=public.battle_today() and player_right is not null order by id limit 1;
 if b.id is null then raise exception 'Missing fixture';end if;
 select md5(string_agg(to_jsonb(p)::text,',' order by p.id)) into before_hash from public.public_profiles p;
 left_view:=public.get_profile_daily_battles(b.player_left)->'today';right_view:=public.get_profile_daily_battles(b.player_right)->'today';
 if left_view->'me'->>'uid'<>b.player_left::text or right_view->'me'->>'uid'<>b.player_right::text then raise exception 'Wrong viewed profile';end if;
 if left_view->'opponent'->>'uid'<>b.player_right::text or right_view->'opponent'->>'uid'<>b.player_left::text then raise exception 'Wrong opponent';end if;
 if left_view->>'myResult'<>'win' or right_view->>'myResult'<>'loss' or (left_view->>'myPoints')::int<>70 or (right_view->>'myPoints')::int<>30 or (right_view->>'myRankDelta')::int<>b.right_rank_delta then raise exception 'Wrong result perspective: left %, right %',left_view,right_view;end if;
 if left_view::text ~ 'email|auth_user_id|balance|optionId' then raise exception 'Private data';end if;
 select md5(string_agg(to_jsonb(p)::text,',' order by p.id)) into after_hash from public.public_profiles p;
 if before_hash<>after_hash then raise exception 'Read changed profile';end if;
end $$;
update public.daily_battles set result='open' where id=(select id from public.daily_battles where day_id=public.battle_today() and player_right is not null order by id limit 1);
do $$
declare b public.daily_battles;left_view jsonb;
begin
 select * into b from public.daily_battles where day_id=public.battle_today() and player_right is not null order by id limit 1;
 left_view:=public.get_profile_daily_battles(b.player_left)->'today';
 if (left_view->>'scoreVisible')::boolean or left_view->>'myPoints' is not null or left_view->>'theirPoints' is not null or left_view->>'myRankDelta' is not null then raise exception 'Open scores leaked';end if;
 if public.get_profile_daily_battles('00000000-0000-0000-0000-000000000000')->>'today' is not null then raise exception 'Unknown profile battle';end if;
 if has_function_privilege('anon','public.get_profile_daily_battles(uuid)','execute') or has_function_privilege('authenticated','public.profile_daily_battle(uuid,date)','execute') then raise exception 'Unexpected permissions';end if;
 if not has_function_privilege('authenticated','public.get_profile_daily_battles(uuid)','execute') then raise exception 'Missing public read';end if;
end $$;
rollback;
select 'Both perspectives, completed/open scores, missing profile, privacy, read-only and permissions OK; fixtures rolled back' as result;




