begin;
select set_config('request.jwt.claims',jsonb_build_object('sub','00000000-0000-0000-0000-000000000001','email',(select owner_email from public.app_config where singleton))::text,true);
do $$
declare g public.predictions; p public.public_profiles; before_green int; before_red int; before_xp bigint; expected_xp int; wrong text; r jsonb; battle_snapshot text;
begin
 select * into g from public.predictions where status='settled' and closes_at<now() order by day_id desc,slot limit 1;
 if not found then raise exception 'Fixture settled required'; end if;
 select * into p from public.public_profiles where player_id=1000006;
 select md5(coalesce(jsonb_agg(to_jsonb(b) order by b.id)::text,'')) into battle_snapshot from public.daily_battles b;
 delete from public.picks where profile_id=p.id and prediction_day=g.day_id and slot=g.slot;
 before_green:=p.green; before_xp:=public.total_xp(p.level,p.xp); expected_xp:=public.pass_xp(5,p.id)+public.pass_xp(25,p.id);
 r:=public.admin_add_pick(p.id,g.day_id,g.slot,g.winning_option_id);
 select * into p from public.public_profiles where id=p.id;
 if p.green<>before_green+1 or public.total_xp(p.level,p.xp)<>before_xp+expected_xp or r->>'status'<>'green' then raise exception 'Green totals failed'; end if;
 begin
   perform public.admin_add_pick(p.id,g.day_id,g.slot,g.winning_option_id);
   raise exception 'Duplicate accepted';
 exception when others then if sqlerrm='Duplicate accepted' then raise; end if; end;
 delete from public.picks where profile_id=p.id and prediction_day=g.day_id and slot=g.slot;
 select o->>'id' into wrong from jsonb_array_elements(g.options) o where o->>'id'<>g.winning_option_id limit 1;
 before_red:=p.red; before_xp:=public.total_xp(p.level,p.xp);
 r:=public.admin_add_pick(p.id,g.day_id,g.slot,wrong);
 select * into p from public.public_profiles where id=p.id;
 if p.red<>before_red+1 or public.total_xp(p.level,p.xp)<>before_xp+public.pass_xp(5,p.id) or r->>'status'<>'red' then raise exception 'Red totals failed'; end if;
 if battle_snapshot<>(select md5(coalesce(jsonb_agg(to_jsonb(b) order by b.id)::text,'')) from public.daily_battles b) then raise exception 'Battle changed'; end if;
 delete from public.picks where profile_id=p.id and prediction_day=g.day_id and slot=g.slot;
 update public.predictions set status='open',winning_option_id=null where day_id=g.day_id and slot=g.slot;
 before_xp:=public.total_xp(p.level,p.xp);
 r:=public.admin_add_pick(p.id,g.day_id,g.slot,wrong);
 select * into p from public.public_profiles where id=p.id;
 if r->>'status'<>'pending' or public.total_xp(p.level,p.xp)<>before_xp+public.pass_xp(5,p.id) then raise exception 'Pending XP failed'; end if;
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-000000000001","email":"notadmin@example.com"}',true);
 begin
   perform public.admin_add_pick(p.id,g.day_id,g.slot,wrong);
   raise exception 'Nonadmin accepted';
 exception when others then if sqlerrm='Nonadmin accepted' then raise; end if; end;
end;
$$;
rollback;
