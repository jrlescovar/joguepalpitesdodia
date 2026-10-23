create temporary table kryptonite_real_profiles as select id,to_jsonb(p) data from public.public_profiles p;
create or replace function public.box_random_index(p_count integer) returns integer language plpgsql volatile as $$begin
 if current_setting('test.kryptonite_rarity',true)='true' then
  perform set_config('test.kryptonite_rarity','false',true);return 95;
 end if;
 return current_setting('test.kryptonite_index')::integer;
end;$$;
do $$declare account uuid:=gen_random_uuid();auth_id uuid:=gen_random_uuid();item_kind text;pool_index integer;request uuid;opening jsonb;replay jsonb;balance_after integer;blocked boolean:=false;begin
 if not exists(select 1 from public.box_style_catalog c where c.style='legend-kryptonite' and c.rarity='legendary' and c.theme='classic' and c.item_kind is null) then raise exception 'Kit classification incorrect';end if;
 if not exists(select 1 from public.box_style_catalog where style='halloween-clown' and rarity='legendary' and theme='halloween') then raise exception 'Original Clown changed';end if;
 insert into public.public_profiles(id,username,avatar_color) values(account,'kryptoniteqa','#3b82f6');
 insert into public.private_profiles(profile_id,auth_user_id,email) values(account,auth_id,account::text||'@qa.invalid');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',auth_id,'role','authenticated')::text,true);
 begin perform public.set_pass_styles('legend-kryptonite','legend-kryptonite'); exception when others then blocked:=true;end;
 if not blocked then raise exception 'Unowned kit equipped';end if;
 insert into public.box_balances(profile_id,balance) values(account,4);
 foreach item_kind in array array['frame','name'] loop
  select position into strict pool_index from (
   select c.style,k.kind,(row_number() over(order by c.style,k.kind)-1)::integer position
   from public.box_style_catalog c cross join (values ('name'),('frame'),('font'))k(kind)
   where c.rarity='legendary' and c.theme='classic' and ((c.item_kind is null and k.kind in ('name','frame')) or c.item_kind=k.kind)
  )pool where style='legend-kryptonite' and kind=item_kind;
  perform set_config('test.kryptonite_index',pool_index::text,true);
  perform set_config('test.kryptonite_rarity','true',true);
  request:=gen_random_uuid();opening:=public.open_box(request);
  if opening->>'style'<>'legend-kryptonite' or opening->>'kind'<>item_kind or opening->>'rarity'<>'legendary' or (opening->>'duplicate')::boolean then raise exception 'Kit did not drop correctly';end if;
  if not public.box_style_allowed(account,item_kind,'legend-kryptonite') then raise exception 'Kit not unlocked';end if;
  balance_after:=(opening->>'balance')::int;replay:=public.open_box(request);
  if replay<>opening or (select balance from public.box_balances where profile_id=account)<>balance_after then raise exception 'Replay spent another box';end if;
  perform set_config('test.kryptonite_rarity','true',true);
  opening:=public.open_box(gen_random_uuid());
  if not (opening->>'duplicate')::boolean or (opening->>'xpAwarded')::int<>1000 then raise exception 'Mythic duplicate XP incorrect';end if;
 end loop;
 perform public.set_pass_styles('legend-kryptonite','legend-kryptonite');
 if not exists(select 1 from public.public_profiles where id=account and pass_name_style='legend-kryptonite' and pass_border_style='legend-kryptonite') then raise exception 'Kit equip failed';end if;
 if exists(select 1 from kryptonite_real_profiles b join public.public_profiles p using(id) where b.data is distinct from to_jsonb(p)) then raise exception 'Real player data changed';end if;
end;$$;
select 'PASS: legendary/event catalog; original Clown intact; unowned blocked; name/frame actual drops; 1000 duplicate XP; idempotent replay; equip; real players unchanged' as result;
