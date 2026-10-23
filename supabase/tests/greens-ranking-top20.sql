begin;
set local statement_timeout='30s';
do $$
declare rows jsonb;expected jsonb;first_ten jsonb;payload jsonb;auth_id uuid;
begin
 rows:=public.get_ranking_top20();
 select coalesce(jsonb_agg(id::text order by position),'[]'::jsonb) into expected from (select id,row_number() over(order by green desc,public.total_xp(level,xp) desc,player_id) as position from public.public_profiles order by green desc,public.total_xp(level,xp) desc,player_id limit 20)t;
 if jsonb_array_length(rows)<>least(20,(select count(*)::int from public.public_profiles)) then raise exception 'Wrong count';end if;
 if (select jsonb_agg(item->>'uid' order by n) from jsonb_array_elements(rows) with ordinality t(item,n)) is distinct from expected then raise exception 'Greens order changed';end if;
 select jsonb_agg(item order by n) into first_ten from jsonb_array_elements(rows) with ordinality t(item,n) where n<=10;
 if first_ten is distinct from public.get_ranking_top10() then raise exception 'Existing top ten changed';end if;
 select auth_user_id into auth_id from public.private_profiles where profile_id=(select id from public.public_profiles where player_id=1000001);
 perform set_config('request.jwt.claim.sub',auth_id::text,true);
 payload:=public.get_tournament_ranking_page();
 if payload->'players' is distinct from rows or payload->'ownRank' is distinct from public.get_my_rank() then raise exception 'Page or own position changed';end if;
 if has_function_privilege('anon','public.get_ranking_top20()','execute') then raise exception 'Anonymous RPC grant';end if;
end $$;
select 'PASS: 20 players; original Greens/XP/playerId ordering; unchanged podium/top10 and own rank; authenticated access' as checks;
rollback;
