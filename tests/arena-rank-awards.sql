begin;
do $$
declare d date:=date '2071-02-01'; a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); other uuid:=gen_random_uuid();
begin
  insert into public.public_profiles(id,player_id,username,avatar_color,rank_points) values
    (a,99000201,'arenaaward1','#3b82f6',200),(b,99000202,'arenaaward2','#3b82f6',200),
    (c,99000203,'arenaaward3','#3b82f6',200),(other,99000204,'arenaaward4','#3b82f6',200);
  insert into public.arena_rounds(day_id) values(d);
  insert into public.arena_entries(day_id,profile_id,seed,qualifying_points,points,greens,level) values
    (d,a,1,200,100,4,2),(d,b,2,200,80,3,2),(d,c,3,200,60,2,2),(d,other,4,200,40,1,2);
  update public.arena_rounds set status='finished',winner_id=a,settled_at=now() where day_id=d;
  if (select count(*) from public.arena_rank_awards where day_id=d)<>3 then raise exception 'Expected three awards'; end if;
  if not exists(select 1 from public.public_profiles where id=a and rank_points=230)
    or not exists(select 1 from public.public_profiles where id=b and rank_points=220)
    or not exists(select 1 from public.public_profiles where id=c and rank_points=210)
    or not exists(select 1 from public.public_profiles where id=other and rank_points=200) then
    raise exception 'Wrong Arena rank points';
  end if;
  perform public.grant_arena_rank_awards(d);
  if (select sum(rank_points) from public.public_profiles where id in (a,b,c,other))<>860 then
    raise exception 'Arena points were credited twice';
  end if;
end;$$;
rollback;
