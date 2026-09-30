begin;

-- Equal scores are draws regardless of greens, level, or entry position.
create or replace function public.battle_winner(
  p_left uuid, p_right uuid,
  p_left_points integer, p_right_points integer,
  p_left_greens integer, p_right_greens integer
)
returns text language sql stable security definer set search_path=public,pg_temp as $$
  select case when p_left_points>p_right_points then 'left'
    when p_right_points>p_left_points then 'right' else 'draw' end;
$$;
revoke all on function public.battle_winner(uuid,uuid,integer,integer,integer,integer) from public,anon,authenticated;

-- Keep the existing settlement and correction paths, changing only their
-- accounting for a draw. Fail the migration if their expected form drifted.
do $$
declare definition text; changed text;
begin
  definition:=pg_get_functiondef('public.finalize_daily_battle(date)'::regprocedure);
  if position('rank_points=greatest(0,rank_points + case outcome when ''left'' then 15 else -15 end)' in definition)=0
    or position('rank_points=greatest(0,rank_points + case outcome when ''right'' then 15 else -15 end)' in definition)=0 then
    raise exception 'Unexpected daily battle settlement definition';
  end if;
  changed:=replace(definition,
    'case outcome when ''left'' then 15 else -15 end',
    'case outcome when ''left'' then 15 when ''right'' then -15 else 0 end');
  changed:=replace(changed,
    'case outcome when ''right'' then 15 else -15 end',
    'case outcome when ''right'' then 15 when ''left'' then -15 else 0 end');
  changed:=replace(changed,
    'battle_losses=battle_losses + (case when outcome=''right'' then 1 else 0 end),',
    'battle_losses=battle_losses + (case when outcome=''right'' then 1 else 0 end), battle_draws=battle_draws + (case when outcome=''draw'' then 1 else 0 end),');
  changed:=replace(changed,
    'battle_losses=battle_losses + (case when outcome=''left'' then 1 else 0 end),',
    'battle_losses=battle_losses + (case when outcome=''left'' then 1 else 0 end), battle_draws=battle_draws + (case when outcome=''draw'' then 1 else 0 end),');
  if changed=definition or position('battle_draws=battle_draws + (case when outcome=''draw'' then 1 else 0 end)' in changed)=0 then
    raise exception 'Daily battle draw accounting was not updated';
  end if;
  execute changed;

  definition:=pg_get_functiondef('public.record_battle_rank_deltas()'::regprocedure);
  if position('else -10 end' in definition)=0 then raise exception 'Unexpected battle delta definition'; end if;
  changed:=replace(definition,'else -10 end','else 0 end');
  execute changed;

  definition:=pg_get_functiondef('public.reconcile_corrected_battle_pick()'::regprocedure);
  if position('left_bonus := case outcome when ''left'' then 15 else -15 end;' in definition)=0
    or position('right_bonus := case outcome when ''right'' then 15 else -15 end;' in definition)=0
    or position('battle_draws = battle_draws - (battle.result = ''draw'')::integer,' in definition)=0 then
    raise exception 'Unexpected battle correction definition';
  end if;
  changed:=replace(definition,
    'left_bonus := case outcome when ''left'' then 15 else -15 end;',
    'left_bonus := case outcome when ''left'' then 15 when ''right'' then -15 else 0 end;');
  changed:=replace(changed,
    'right_bonus := case outcome when ''right'' then 15 else -15 end;',
    'right_bonus := case outcome when ''right'' then 15 when ''left'' then -15 else 0 end;');
  changed:=replace(changed,
    'battle_draws = battle_draws - (battle.result = ''draw'')::integer,',
    'battle_draws = battle_draws + (outcome = ''draw'')::integer - (battle.result = ''draw'')::integer,');
  execute changed;
end;$$;

notify pgrst,'reload schema';
commit;
