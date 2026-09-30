begin;

insert into public.public_profiles(id,player_id,username,avatar_color)
values('00000000-0000-0000-0000-000000990400',99000400,'pushfixture','#3b82f6');
insert into public.predictions(day_id,slot,title,options,closes_at)
values(date '2071-03-01',0,'Palpite para teste de aviso',
  '[{"id":"a","label":"Sim","rankPoints":5},{"id":"b","label":"Não","rankPoints":15}]',
  now()+interval '20 minutes');
insert into public.push_preferences(profile_id,available,reminder,result)
values('00000000-0000-0000-0000-000000990400',true,false,false);
insert into public.push_subscriptions(endpoint,profile_id,p256dh,auth_secret)
values('https://fcm.googleapis.com/fcm/send/test-fixture',
  '00000000-0000-0000-0000-000000990400',repeat('a',87),repeat('b',22));

do $$
begin
  if (select count(*) from public.get_push_recipients('available',date '2071-03-01',0::smallint)
      where endpoint='https://fcm.googleapis.com/fcm/send/test-fixture')<>1
    or (select count(*) from public.get_push_recipients('reminder',date '2071-03-01',0::smallint))<>0
    or (select count(*) from public.get_push_recipients('result',date '2071-03-01',0::smallint))<>0 then
    raise exception 'Unanswered eligible player was not selected exclusively for available alerts';
  end if;
end;
$$;

insert into public.picks(profile_id,prediction_day,slot,option_id)
values('00000000-0000-0000-0000-000000990400',date '2071-03-01',0,'a');

do $$
begin
  if (select count(*) from public.get_push_recipients('available',date '2071-03-01',0::smallint)
      where endpoint='https://fcm.googleapis.com/fcm/send/test-fixture')<>0 then
    raise exception 'Player with a pick was selected for an open-pick alert';
  end if;
end;
$$;

delete from public.picks where profile_id='00000000-0000-0000-0000-000000990400'
  and prediction_day=date '2071-03-01' and slot=0;

do $$
begin
  if not public.claim_push_delivery('available',date '2071-03-01',0::smallint,
      'https://fcm.googleapis.com/fcm/send/test-fixture')
    or public.claim_push_delivery('available',date '2071-03-01',0::smallint,
      'https://fcm.googleapis.com/fcm/send/test-fixture') then
    raise exception 'Duplicate available delivery was not blocked';
  end if;
end;
$$;

rollback;
