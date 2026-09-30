create or replace function public.get_battle_pick_comparison(p_day_id date, p_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth,pg_temp as $$
declare battle public.daily_battles; opponent_id uuid; comparison jsonb;
begin
  if auth.uid() is null then raise exception 'Entre para ver a comparação da batalha.'; end if;
  select * into battle from public.daily_battles
    where day_id=p_day_id and result in ('left','right','draw')
      and player_right is not null and p_profile_id in (player_left,player_right);
  if not found then return null; end if;
  opponent_id := case when battle.player_left=p_profile_id then battle.player_right else battle.player_left end;

  select coalesce(jsonb_agg(jsonb_build_object(
    'slot',g.slot,'title',g.title,
    'correctOption',(select o->>'label' from jsonb_array_elements(g.options) o where o->>'id'=g.winning_option_id limit 1),
    'myOption',(select o->>'label' from jsonb_array_elements(g.options) o where o->>'id'=mine.option_id limit 1),
    'theirOption',(select o->>'label' from jsonb_array_elements(g.options) o where o->>'id'=theirs.option_id limit 1),
    'myPoints',case when mine.status='green' then coalesce((select (o->>'rankPoints')::integer from jsonb_array_elements(g.options) o where o->>'id'=mine.option_id limit 1),0) else 0 end,
    'theirPoints',case when theirs.status='green' then coalesce((select (o->>'rankPoints')::integer from jsonb_array_elements(g.options) o where o->>'id'=theirs.option_id limit 1),0) else 0 end
  ) order by g.slot),'[]'::jsonb) into comparison
  from public.predictions g
  left join public.picks mine on mine.prediction_day=g.day_id and mine.slot=g.slot and mine.profile_id=p_profile_id
  left join public.picks theirs on theirs.prediction_day=g.day_id and theirs.slot=g.slot and theirs.profile_id=opponent_id
  where g.day_id=p_day_id and g.status='settled';

  return comparison;
end;
$$;

revoke all on function public.get_battle_pick_comparison(date,uuid) from public,anon,authenticated;
grant execute on function public.get_battle_pick_comparison(date,uuid) to authenticated;
