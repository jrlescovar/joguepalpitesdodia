begin;
do $$
declare owner_id uuid; owner_auth uuid; other_id uuid; other_auth uuid; preview text; owner_name text;
begin
 select p.id,v.auth_user_id,p.username into strict owner_id,owner_auth,owner_name from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where player_id=1000001;
 select p.id,v.auth_user_id into strict other_id,other_auth from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where player_id<>1000001 and v.auth_user_id is not null order by player_id limit 1;
 foreach preview in array array['preview-rubikglitch','preview-rubikwetpaint','preview-rubikdirt','preview-rampartone','preview-tiltprism','preview-shojumaru','preview-tradewinds','preview-sedgwickavedisplay','preview-yatraone','preview-fugazone'] loop
  if exists(select 1 from public.box_style_catalog where style=preview) then raise exception 'Preview entered loot pool'; end if;
  perform set_config('request.jwt.claim.sub',owner_auth::text,true);
  if not public.username_font_allowed(owner_id,preview) then raise exception 'Owner preview unavailable %',preview; end if;
  perform public.set_username_font(preview);
  if public.profile_json(owner_id)->>'usernameFont'<>preview or public.username_font_for(owner_name)<>preview then raise exception 'Owner preview masked'; end if;
  perform set_config('request.jwt.claim.sub',other_auth::text,true);
  if public.username_font_allowed(other_id,preview) or public.username_font_allowed(owner_id,preview) then raise exception 'Preview leaked to another user'; end if;
  if public.profile_json(owner_id)->>'usernameFont'<>'normal' or public.get_public_profile(owner_id)->>'usernameFont'<>'normal' or public.username_font_for(owner_name)<>'normal' then raise exception 'Public response exposed preview'; end if;
  begin
   perform public.set_username_font(preview);
   raise exception 'Other player equipped preview';
  exception when raise_exception then
   if sqlerrm<>'Fonte indisponível para esta conta.' then raise; end if;
  end;
  begin
   update public.public_profiles set username_font=preview where id=other_id;
   raise exception 'Other player bypassed preview constraint';
  exception when check_violation then null; end;
 end loop;
 perform set_config('request.jwt.claim.sub',owner_auth::text,true);
 if public.username_font_allowed(owner_id,'preview-teko') or public.username_font_allowed(owner_id,'preview-unknown') then raise exception 'Retired or unknown preview accepted'; end if;
 if not exists(select 1 from public.box_style_catalog where style='marckscript' and rarity='legendary' and item_kind='font' and theme='classic') then raise exception 'Marck Script not legendary'; end if;
 if has_function_privilege('authenticated','public.username_font_allowed(uuid,text)','execute') or has_function_privilege('anon','public.set_username_font(text)','execute') then raise exception 'Helper permissions weakened'; end if;
end; $$;
rollback;
