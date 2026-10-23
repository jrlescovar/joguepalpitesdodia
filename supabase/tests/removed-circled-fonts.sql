begin;
-- All writes and forced draws in this verification are rolled back.
create or replace function public.box_random_index(p_count integer) returns integer
language plpgsql volatile security definer set search_path=public,pg_temp as $$
begin
 if current_setting('test.font_removal_next_roll',true)='true' then
  perform set_config('test.font_removal_next_roll','false',true);
  return current_setting('test.font_removal_roll')::integer;
 end if;
 return 0;
end;$$;

do $$
declare
 removed text[]:=array['blackopsone','audiowide','arbutus','miltoniantattoo','creepster','specialelite','rubikdirt','shojumaru','allertastencil','barrio','rubikmoonrocks','rampartone','kumaroneoutline'];
 target uuid; target_auth uuid; font text; mode text; roll integer;
 request uuid; result jsonb; replay jsonb; amount integer; balances integer[]; after_balances integer[];
begin
 select array_agg(style) into removed from (select unnest(removed) style union all select 'preview-'||unnest(removed)) fonts;
 select p.id,v.auth_user_id into strict target,target_auth from public.public_profiles p
 join public.private_profiles v on v.profile_id=p.id where p.player_id=1000001;
 perform set_config('request.jwt.claim.sub',target_auth::text,true);
 if exists(select 1 from public.public_profiles where username_font=any(removed))
 or exists(select 1 from public.box_style_catalog where style=any(removed))
 or exists(select 1 from public.box_inventory where style=any(removed))
 or exists(select 1 from public.player_mail where style=any(removed))
 or exists(select 1 from public.box_openings where style=any(removed))
 or exists(select 1 from public.level_drops where reward->>'style'=any(removed))
 or exists(select 1 from public.level_drop_xp_repairs where previous_reward->>'style'=any(removed))
 or exists(select 1 from public.level_drop_requests where response->'reward'->>'style'=any(removed))
 then raise exception 'Removed font data remains'; end if;
 foreach font in array removed loop
  if public.username_font_allowed(target,font) then raise exception 'Owner can still equip %',font; end if;
  begin
   perform public.set_username_font(font);
   raise exception 'Removed font equipped: %',font;
  exception when raise_exception then
   if sqlerrm<>'Fonte indisponível para esta conta.' then raise; end if;
  end;
  begin
   update public.public_profiles set username_font=font where id=target;
   raise exception 'Direct font write accepted: %',font;
  exception when check_violation then null; end;
  begin
   insert into public.box_style_catalog(style,rarity,item_kind,theme) values(font,'rare','font','classic');
   raise exception 'Removed font catalog write accepted: %',font;
  exception when check_violation then null; end;
 end loop;
 if public.set_username_font('normal')->>'usernameFont'<>'normal' then raise exception 'Default font unavailable'; end if;
 if public.set_username_font('quantico')->>'usernameFont'<>'quantico' then raise exception 'Surviving font unavailable'; end if;
 if exists(select 1 from jsonb_array_elements(public.get_box_state()->'inventory') i where i->>'style'=any(removed)) then raise exception 'Removed font in inventory response'; end if;

 insert into public.box_balances(profile_id,balance) values(target,20) on conflict(profile_id) do update set balance=20;
 insert into public.font_box_balances(profile_id,balance) values(target,20) on conflict(profile_id) do update set balance=20;
 insert into public.halloween_box_balances(profile_id,balance) values(target,20) on conflict(profile_id) do update set balance=20;
 foreach mode in array array['classic','font','halloween'] loop
  foreach roll in array case mode when 'classic' then array[0,40,70,85,95] when 'font' then array[0,45,80,95] else array[0,60,90] end loop
   perform set_config('test.font_removal_roll',roll::text,true);
   perform set_config('test.font_removal_next_roll','true',true);
   request:=gen_random_uuid();
   result:=case mode when 'classic' then public.open_box(request) when 'font' then public.open_font_box(request) else public.open_halloween_box(request) end;
   if result->>'style' is null or result->>'style'=any(removed) then raise exception 'Invalid box delivery % %',mode,result; end if;
   balances:=array[(select balance from public.box_balances where profile_id=target),(select balance from public.font_box_balances where profile_id=target),(select balance from public.halloween_box_balances where profile_id=target)];
   replay:=case mode when 'classic' then public.open_box(request) when 'font' then public.open_font_box(request) else public.open_halloween_box(request) end;
   after_balances:=array[(select balance from public.box_balances where profile_id=target),(select balance from public.font_box_balances where profile_id=target),(select balance from public.halloween_box_balances where profile_id=target)];
   if replay is distinct from result or balances is distinct from after_balances then raise exception 'Box replay changed reward or balance'; end if;
  end loop;
 end loop;
 -- An anonymized old receipt must remain a replay guard, without granting a box/item again.
 select o.request_id into request from public.box_openings o where o.profile_id=target and o.style like 'removed-font-%' limit 1;
 if request is not null then
  select balance into amount from public.font_box_balances where profile_id=target;
  result:=public.open_font_box(request);
  if result->>'style' not like 'removed-font-%' or amount<>(select balance from public.font_box_balances where profile_id=target) then raise exception 'Retired receipt replay consumed a box'; end if;
 end if;
end $$;
select 'PASS: 26 font identifiers blocked; remaining box rarities and replay guards verified' as result;
rollback;
