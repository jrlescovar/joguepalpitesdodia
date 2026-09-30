begin;
do $$
declare d date:=date '2071-03-01'; player uuid:=gen_random_uuid(); endpoint text:='https://fcm.googleapis.com/fcm/send/test-fixture';
begin
  insert into public.public_profiles(id,player_id,username,avatar_color) values(player,99000400,'pushfixture','#3b82f6');
  insert into public.predictions(day_id,slot,title,options,closes_at)
    values(d,0,'Palpite para teste de aviso','[{"id":"a","label":"Sim","rankPoints":5},{"id":"b","label":"Não","rankPoints":15}]',now()+interval '20 minutes');
  insert into public.push_preferences(profile_id,available,reminder,result) values(player,true,true,true);
  insert into public.push_subscriptions(endpoint,profile_id,p256dh,auth_secret)
    values(endpoint,player,repeat('a',87),repeat('b',22));
  if (select count(*) from public.get_push_recipients('available',d,0::smallint))<>1
    or (select count(*) from public.get_push_recipients('reminder',d,0::smallint))<>1 then
    raise exception 'Unanswered eligible player was not selected';
  end if;
  insert into public.picks(profile_id,prediction_day,slot,option_id) values(player,d,0,'a');
  if (select count(*) from public.get_push_recipients('available',d,0::smallint))<>0
    or (select count(*) from public.get_push_recipients('reminder',d,0::smallint))<>0 then
    raise exception 'Player with a pick was selected for an open-pick alert';
  end if;
  update public.predictions set status='settled',winning_option_id='a',settled_at=now() where day_id=d and slot=0;
  if (select count(*) from public.get_push_recipients('result',d,0::smallint))<>1 then
    raise exception 'Result subscriber was not selected';
  end if;
  if not public.claim_push_delivery('result',d,0::smallint,endpoint)
    or public.claim_push_delivery('result',d,0::smallint,endpoint) then
    raise exception 'Duplicate result delivery was not blocked';
  end if;
end;
$$;
rollback;
