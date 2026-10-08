begin;

-- Normalize the pair so switching left/right cannot bypass the daily rule.
create index daily_battles_opponent_history on public.daily_battles
 (day_id,least(player_left,player_right),greatest(player_left,player_right))
 where player_right is not null;

create function public.daily_battle_opponents_allowed(p_day date,p_left uuid,p_right uuid)
returns boolean language sql volatile security definer set search_path=public,auth,pg_temp as $$
 select p_left is not null and p_right is not null and not exists (
  select 1 from public.daily_battles b
  where b.player_right is not null
   and ((b.day_id=p_day-1 and p_day>=date '2026-10-01')
     or (b.day_id=p_day+1 and b.day_id>=date '2026-10-01'))
   and least(b.player_left,b.player_right)=least(p_left,p_right)
   and greatest(b.player_left,b.player_right)=greatest(p_left,p_right)
 );
$$;
revoke all on function public.daily_battle_opponents_allowed(date,uuid,uuid) from public,anon,authenticated;

-- The same rule applies to the initial draw, reservations, gap fallback and
-- late entrants. If yesterday's rival is the only candidate, keep the bye.
do $$
declare definition text; anchor text;
begin
 definition:=pg_get_functiondef('public.ensure_daily_battle_round(date)'::regprocedure);
 anchor:='select day_id,player_left,player_right from public.daily_battle_reserved_pairings where day_id=p_day;';
 if position(anchor in definition)=0 then raise exception 'Unexpected reserved draw definition'; end if;
 definition:=replace(definition,anchor,
  'select day_id,player_left,player_right from public.daily_battle_reserved_pairings where day_id=p_day and public.daily_battle_opponents_allowed(p_day,player_left,player_right);');
 anchor:='where p.id=any(available) and public.battle_compatible(player.rank_points,p.rank_points)';
 if position(anchor in definition)=0 then raise exception 'Unexpected initial draw definition'; end if;
 definition:=replace(definition,anchor,anchor || chr(10) ||
  '        and public.daily_battle_opponents_allowed(p_day,player.id,p.id)');
 execute definition;

 definition:=pg_get_functiondef('public.pair_waiting_daily_battles(date)'::regprocedure);
 anchor:='and l.player_right is null and r.player_right is null';
 if position(anchor in definition)=0 then raise exception 'Unexpected fallback draw definition'; end if;
 definition:=replace(definition,anchor,anchor || chr(10) ||
  '        and public.daily_battle_opponents_allowed(p_day,l.player_left,r.player_left)');
 execute definition;

 definition:=pg_get_functiondef('public.join_daily_battle_bye(uuid,date)'::regprocedure);
 anchor:='where b.day_id=p_day and b.result=''open'' and b.player_right is null';
 if position(anchor in definition)=0 then raise exception 'Unexpected late-entry draw definition'; end if;
 definition:=replace(definition,anchor,anchor || chr(10) ||
  '        and public.daily_battle_opponents_allowed(p_day,p_profile,b.player_left)');
 execute definition;
end;
$$;

-- Protect direct server writes too. Existing settled rows are not rewritten,
-- and score/result updates do not change the players and never redraw a battle.
create function public.guard_consecutive_battle_opponents()
returns trigger language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
 if new.player_right is null then return new; end if;
 if tg_op='UPDATE' then
  if (new.day_id,new.player_left,new.player_right) is not distinct from
   (old.day_id,old.player_left,old.player_right) then return new; end if;
 end if;
 -- Serializing an unordered pair also prevents concurrent adjacent-day inserts
 -- from both accepting it. The forward check covers rounds saved out of order.
 perform pg_advisory_xact_lock(hashtext('daily-battle-opponents-' || least(new.player_left,new.player_right)::text || ':' || greatest(new.player_left,new.player_right)::text));
 if not public.daily_battle_opponents_allowed(new.day_id,new.player_left,new.player_right) then
  raise exception 'O mesmo adversário não pode se repetir em dias consecutivos.' using errcode='23514';
 end if;
 return new;
end;
$$;
revoke all on function public.guard_consecutive_battle_opponents() from public,anon,authenticated;
create trigger no_consecutive_battle_opponents
before insert or update of day_id,player_left,player_right on public.daily_battles
for each row execute function public.guard_consecutive_battle_opponents();

revoke all on function public.ensure_daily_battle_round(date),public.pair_waiting_daily_battles(date),public.join_daily_battle_bye(uuid,date) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
