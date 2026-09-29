begin;
do $$
declare p uuid; g public.predictions; cur int; peak int;
begin
 select id into p from public.public_profiles where player_id=1000006;
 select * into g from public.predictions order by day_id desc,slot limit 1;
 delete from public.picks where profile_id=p;
 update public.public_profiles set red_streak_current=0,red_streak_max=0 where id=p;
 insert into public.picks(profile_id,prediction_day,slot,option_id,status,settled_at) values(p,g.day_id,g.slot,g.options->0->>'id','pending',null);
 update public.picks set status='red',settled_at=now() where profile_id=p;
 select red_streak_current,red_streak_max into cur,peak from public.public_profiles where id=p;
 if cur<>1 or peak<>1 then raise exception 'First red failed'; end if;
 delete from public.picks where profile_id=p;
 insert into public.picks(profile_id,prediction_day,slot,option_id,status,settled_at) values(p,g.day_id,g.slot,g.options->0->>'id','red',now());
 select red_streak_current,red_streak_max into cur,peak from public.public_profiles where id=p;
 if cur<>2 or peak<>2 then raise exception 'Second red or retained history failed'; end if;
 delete from public.picks where profile_id=p;
 insert into public.picks(profile_id,prediction_day,slot,option_id,status,settled_at) values(p,g.day_id,g.slot,g.options->0->>'id','green',now());
 select red_streak_current,red_streak_max into cur,peak from public.public_profiles where id=p;
 if cur<>0 or peak<>2 then raise exception 'Green reset failed'; end if;
 update public.picks set status='red' where profile_id=p;
 select red_streak_current,red_streak_max into cur,peak from public.public_profiles where id=p;
 if cur<>1 or peak<>2 then raise exception 'Correction failed'; end if;
 if (public.profile_json(p)->>'redStreakCurrent')::int<>1 then raise exception 'JSON missing reds'; end if;
end;$$;
rollback;
