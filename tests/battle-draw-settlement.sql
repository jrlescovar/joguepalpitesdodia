begin;
create or replace function public.battle_today() returns date language sql stable as $$
  select date '2070-01-03';
$$;
do $$
declare
  day date:=date '2070-01-03';
  left_id uuid:=gen_random_uuid(); right_id uuid:=gen_random_uuid();
  battle_id bigint:=-990108;
  left_rank integer; right_rank integer;
begin
  insert into public.public_profiles(id,player_id,username,avatar_color,rank_points)
    values(left_id,99000108,'btstdrawa','#3b82f6',300),
          (right_id,99000109,'btstdrawb','#3b82f6',300);
  insert into public.daily_battle_rounds(day_id) values(day);
  insert into public.daily_battles(id,day_id,player_left,player_right) overriding system value
    values(battle_id,day,left_id,right_id);
  insert into public.predictions(day_id,slot,title,options,closes_at)
    values(day,0,'Teste de empate por pontos',
      '[{"id":"1","label":"Sim","rankPoints":108},{"id":"2","label":"Não","rankPoints":10}]',
      now()-interval '1 hour');
  insert into public.picks(profile_id,prediction_day,slot,option_id,status)
    values(left_id,day,0,'1','green'),(right_id,day,0,'1','green');
  select rank_points into left_rank from public.public_profiles where id=left_id;
  select rank_points into right_rank from public.public_profiles where id=right_id;
  update public.predictions set status='settled',winning_option_id='1',settled_at=now()
    where day_id=day and slot=0;
  perform public.finalize_daily_battle(day);
  if not exists(select 1 from public.daily_battles where id=battle_id and result='draw'
      and left_points=108 and right_points=108 and left_rank_delta=0 and right_rank_delta=0) then
    raise exception '108 x 108 did not close as a zero-point draw';
  end if;
  if not exists(select 1 from public.public_profiles where id=left_id and rank_points=left_rank
      and battle_wins=0 and battle_losses=0 and battle_draws=1)
    or not exists(select 1 from public.public_profiles where id=right_id and rank_points=right_rank
      and battle_wins=0 and battle_losses=0 and battle_draws=1) then
    raise exception 'Draw changed rank or did not record both draws';
  end if;
  update public.picks set status='red' where profile_id=right_id and prediction_day=day and slot=0;
  if not exists(select 1 from public.daily_battles where id=battle_id and result='left'
      and left_rank_delta=15 and right_rank_delta=-15) then
    raise exception 'Correction from draw to win failed';
  end if;
  update public.picks set status='green' where profile_id=right_id and prediction_day=day and slot=0;
  if not exists(select 1 from public.daily_battles where id=battle_id and result='draw'
      and left_rank_delta=0 and right_rank_delta=0) then
    raise exception 'Correction back to draw failed';
  end if;
  if not exists(select 1 from public.public_profiles where id=left_id and rank_points=left_rank
      and battle_draws=1 and battle_wins=0 and battle_losses=0)
    or not exists(select 1 from public.public_profiles where id=right_id and rank_points=right_rank
      and battle_draws=1 and battle_wins=0 and battle_losses=0) then
    raise exception 'Correction back to draw changed rank or totals';
  end if;
end;$$;
rollback;
