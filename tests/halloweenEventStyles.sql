begin;
-- Exercise actual delivery and equip APIs deterministically; revert all data.
create or replace function public.box_random_index(p_count integer) returns integer language plpgsql volatile security definer set search_path=public,pg_temp as $$
begin
 return case when p_count=100 then current_setting('test.event_roll')::integer else current_setting('test.event_index')::integer end;
end;$$;
do $$
declare target uuid; target_auth uuid; event_style text; event_kind text; expected_rarity text; draw_index integer;
 request uuid; result jsonb; equipped jsonb; snapshot jsonb; classic_balance integer;
begin
 select p.id,v.auth_user_id into strict target,target_auth from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id<>1000001 and v.auth_user_id is not null order by p.player_id limit 1;
 perform set_config('request.jwt.claim.sub',target_auth::text,true);
 perform public.set_pass_styles('none','none');
 delete from public.box_inventory where profile_id=target and style in ('lab-blue-9','lab-blue-10-jade-sky');
 select balance into classic_balance from public.box_balances where profile_id=target;
 insert into public.halloween_box_balances(profile_id,balance) values(target,20) on conflict(profile_id) do update set balance=20;
 foreach event_style in array array['lab-blue-9','lab-blue-10-jade-sky'] loop
  expected_rarity:=case when event_style='lab-blue-9' then 'legendary' else 'mythic' end;
  if not exists(select 1 from public.box_style_catalog where style=event_style and theme='halloween' and rarity=expected_rarity and item_kind is null) then raise exception 'Incorrect event catalog %',event_style; end if;
  if public.box_style_allowed(target,'name',event_style) or public.box_style_allowed(target,'frame',event_style) then raise exception 'Unowned event allowed %',event_style; end if;
  begin
   perform public.set_pass_styles(event_style,event_style);
   raise exception 'Unowned event equip bypassed %',event_style;
  exception when raise_exception then
   if sqlerrm<>'Este estilo ainda não foi desbloqueado.' then raise; end if;
  end;
  foreach event_kind in array array['name','frame'] loop
   select position into strict draw_index from (
    select c.style,k.kind,(row_number() over(order by c.style,k.kind)-1)::integer position
    from public.box_style_catalog c cross join (values ('name'),('frame'),('font')) k(kind)
    where c.rarity=expected_rarity and c.theme='halloween' and ((c.item_kind is null and k.kind in ('name','frame')) or c.item_kind=k.kind)
   ) pool where style=event_style and kind=event_kind;
   perform set_config('test.event_roll',case when expected_rarity='legendary' then '95' else '65' end,true);
   perform set_config('test.event_index',draw_index::text,true);
   request:=gen_random_uuid();
   result:=public.open_halloween_box(request);
   if result->>'style'<>event_style or result->>'kind'<>event_kind or result->>'rarity'<>expected_rarity or (result->>'duplicate')::boolean then raise exception 'Incorrect delivery % %',event_style,event_kind; end if;
   if result<>public.open_halloween_box(request) then raise exception 'Opening not idempotent'; end if;
   if not public.box_style_allowed(target,event_kind,event_style) or public.box_style_allowed(target,'font',event_style) then raise exception 'Incorrect ownership permissions'; end if;
   equipped:=public.get_pass_status();
   equipped:=public.set_pass_styles(case when event_kind='frame' then event_style else equipped->>'borderStyle' end,case when event_kind='name' then event_style else equipped->>'nameStyle' end);
   if equipped->>(case when event_kind='frame' then 'borderStyle' else 'nameStyle' end)<>event_style then raise exception 'Equip response masked event'; end if;
   snapshot:=public.profile_json(target);
   if snapshot->>(case when event_kind='frame' then 'passBorderStyle' else 'passNameStyle' end)<>event_style then raise exception 'Profile response masked event'; end if;
   if not exists(select 1 from jsonb_array_elements(public.get_box_state()->'inventory') item where item->>'style'=event_style and item->>'kind'=event_kind and item->>'rarity'=expected_rarity) then raise exception 'Profile inventory missing event'; end if;
   if not exists(select 1 from jsonb_array_elements(public.get_halloween_box_state()->'inventory') item where item->>'style'=event_style and item->>'kind'=event_kind) then raise exception 'Halloween inventory missing event'; end if;
   result:=public.open_halloween_box(gen_random_uuid());
   if not (result->>'duplicate')::boolean or (result->>'xpAwarded')::integer<>(case when expected_rarity='legendary' then 500 else 250 end) then raise exception 'Incorrect duplicate XP'; end if;
  end loop;
 end loop;
 if (select balance from public.halloween_box_balances where profile_id=target)<>12 then raise exception 'Incorrect Halloween balance'; end if;
 if (select balance from public.box_balances where profile_id=target) is distinct from classic_balance then raise exception 'Classic balance changed'; end if;
 if public.box_style_allowed(target,'name','lab-blue-10-borealis') or public.box_style_allowed(target,'frame','lab-blue-6') then raise exception 'Private style became public'; end if;
end; $$;
rollback;
