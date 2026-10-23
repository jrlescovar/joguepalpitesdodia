begin;
-- Preserve already assigned opponents. Masters in the top ten draw from Masters,
-- without preferring another top-ten player or the closest Master score.
do $$
declare definition text;marker text;
begin
 definition:=pg_get_functiondef('public.pair_top10_daily_battles(date)'::regprocedure);
 marker:='case when r.id=any(required) then 0 else 1 end,';
 if position(marker in definition)=0 then raise exception 'Unexpected top-ten preference';end if;
 definition:=replace(definition,marker,'');
 marker:='ceil(abs(l.points::bigint-r.points::bigint)/100.0),random()';
 if position(marker in definition)=0 then raise exception 'Unexpected Master distance ordering';end if;
 definition:=replace(definition,marker,'case when l.points>=2100 and r.points>=2100 then 0 else ceil(abs(l.points::bigint-r.points::bigint)/100.0) end,random()');
 marker:='and public.daily_battle_opponents_allowed(p_day,l.id,r.id)';
 if position(marker in definition)=0 then raise exception 'Unexpected priority candidate filter';end if;
 definition:=replace(definition,marker,'and (l.points<2100 or r.points>=2100) '||marker);
 execute definition;
 -- The general fallback must not re-pair a waiting top-ten Master below 2100.
 definition:=pg_get_functiondef('public.pair_waiting_daily_battles(date)'::regprocedure);
 definition:=replace(definition,'declare max_gap integer; pairing record;','declare max_gap integer; pairing record; leaders uuid[];');
 marker:='foreach max_gap in array array[200,300,400,500] loop';
 if position(marker in definition)=0 then raise exception 'Unexpected fallback phases';end if;
 definition:=replace(definition,marker,'select array_agg(id) into leaders from (select id from public.public_profiles order by rank_points desc,player_id limit 10) ranked;'||chr(10)||marker);
 marker:='and public.daily_battle_opponents_allowed(p_day,l.player_left,r.player_left)';
 if position(marker in definition)=0 then raise exception 'Unexpected waiting candidate filter';end if;
 definition:=replace(definition,marker,marker||chr(10)||
 'and (not(l.player_left=any(leaders)) or coalesce(l.left_start_rank_points,lp.rank_points)<2100 or coalesce(r.left_start_rank_points,rp.rank_points)>=2100)'||chr(10)||
 'and (not(r.player_left=any(leaders)) or coalesce(r.left_start_rank_points,rp.rank_points)<2100 or coalesce(l.left_start_rank_points,lp.rank_points)>=2100)');
 execute definition;
 definition:=pg_get_functiondef('public.join_daily_battle_bye(uuid,date)'::regprocedure);
 marker:='and public.daily_battle_opponents_allowed(p_day,p_profile,b.player_left)';
 if position(marker in definition)=0 then raise exception 'Unexpected late-entry filter';end if;
 definition:=replace(definition,marker,marker||chr(10)||
 'and (player.rank_points<2100 or p_profile not in (select id from public.public_profiles order by rank_points desc,player_id limit 10) or coalesce(b.left_start_rank_points,p.rank_points)>=2100)'||chr(10)||
 'and (coalesce(b.left_start_rank_points,p.rank_points)<2100 or b.player_left not in (select id from public.public_profiles order by rank_points desc,player_id limit 10) or player.rank_points>=2100)');
 execute definition;
end $$;
notify pgrst,'reload schema';
commit;
