begin;
-- Force the legendary rarity and the exact sorted item for both event prizes.
create or replace function public.box_random_index(p_count integer) returns integer
language plpgsql volatile set search_path=public,pg_temp as $$
begin
 if current_setting('test.soul_next_rarity',true)='true' then
  perform set_config('test.soul_next_rarity','false',true);return 95;
 end if;
 return current_setting('test.soul_item_index')::integer;
end;$$;
do $$
<<soul>>
declare target uuid; target_auth uuid; owner_id uuid; kind text; pool_index integer; result jsonb; retry jsonb; request uuid;
begin
 select p.id,v.auth_user_id into strict target,target_auth from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id<>1000001 and v.auth_user_id is not null order by p.player_id limit 1;
 select id into strict owner_id from public.public_profiles where player_id=1000001;
 if not exists(select 1 from public.box_style_catalog where style='lab-blue-6' and rarity='legendary' and item_kind is null and theme='halloween') then raise exception 'Wrong soul catalog entry'; end if;
 perform set_config('request.jwt.claim.sub',target_auth::text,true);
 update public.public_profiles set pass_border_style='none',pass_name_style='none' where id=target;
 delete from public.box_inventory where profile_id=target and style='lab-blue-6';
 if public.box_style_allowed(target,'name','lab-blue-6') or public.box_style_allowed(target,'frame','lab-blue-6') then raise exception 'Event item allowed before unlock'; end if;
 begin perform public.set_pass_styles('lab-blue-6','lab-blue-6');raise exception 'Expected locked style rejection'; exception when others then if sqlerrm not like 'Este estilo ainda%' then raise; end if; end;
 insert into public.halloween_box_balances(profile_id,balance) values(target,10) on conflict(profile_id) do update set balance=10;
 foreach kind in array array['frame','name'] loop
  select idx into strict pool_index from (
   select c.style,k.kind,row_number() over(order by c.style,k.kind)-1 as idx
   from public.box_style_catalog c cross join (values('name'),('frame'),('font')) k(kind)
   where c.theme='halloween' and c.rarity='legendary' and ((c.item_kind is null and k.kind in ('name','frame')) or c.item_kind=k.kind)
  ) pool where pool.style='lab-blue-6' and pool.kind=soul.kind;
  perform set_config('test.soul_item_index',pool_index::text,true);
  perform set_config('test.soul_next_rarity','true',true);
  request:=gen_random_uuid();result:=public.open_halloween_box(request);
  if result->>'kind'<>kind or result->>'style'<>'lab-blue-6' or result->>'rarity'<>'legendary' or (result->>'duplicate')::boolean then raise exception 'Event draw/unlock incorrect'; end if;
  retry:=public.open_halloween_box(request);
  if retry<>result then raise exception 'Opening retry not idempotent'; end if;
  if not public.box_style_allowed(target,kind,'lab-blue-6') then raise exception 'Won item not equipable'; end if;
  if kind='frame' then
   if public.box_style_allowed(target,'name','lab-blue-6') then raise exception 'Frame also unlocked name'; end if;
   perform public.set_pass_styles('lab-blue-6','none');
  else perform public.set_pass_styles('lab-blue-6','lab-blue-6');end if;
  perform set_config('test.soul_next_rarity','true',true);
  result:=public.open_halloween_box(gen_random_uuid());
  if not (result->>'duplicate')::boolean or (result->>'xpAwarded')::integer<>500 then raise exception 'Legendary duplicate XP incorrect'; end if;
 end loop;
 if not exists(select 1 from public.public_profiles where id=target and pass_name_style='lab-blue-6' and pass_border_style='lab-blue-6') then raise exception 'Style constraints block event winner'; end if;
 result:=public.get_public_profile(target);
 if result->>'passNameStyle' is distinct from 'lab-blue-6' or result->>'passBorderStyle' is distinct from 'lab-blue-6' then raise exception 'Public profile omitted won style'; end if;
 if not public.box_style_allowed(owner_id,'name','lab-blue-6') or not public.box_style_allowed(owner_id,'frame','lab-blue-6') then raise exception 'Owner lost style access'; end if;
 if public.box_style_allowed(target,'name','lab-blue-4') or public.box_style_allowed(target,'frame','lab-blue-4') then raise exception 'Unrelated private style exposed'; end if;
 if (select balance from public.halloween_box_balances where profile_id=target)<>6 then raise exception 'Incorrect box debit'; end if;
end;$$;
rollback;
