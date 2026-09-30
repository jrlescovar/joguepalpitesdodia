-- Run against a test or linked database. Every profile change is rolled back.
begin;
do $$
declare owner_id uuid; owner_auth uuid; other_id uuid; other_auth uuid; item text; result jsonb;
begin
 select p.id,v.auth_user_id into strict owner_id,owner_auth from public.public_profiles p
 join public.private_profiles v on v.profile_id=p.id where p.player_id=1000001;
 select p.id,v.auth_user_id into strict other_id,other_auth from public.public_profiles p
 join public.private_profiles v on v.profile_id=p.id where p.player_id<>1000001 limit 1;
 perform set_config('request.jwt.claim.sub',owner_auth::text,true);
 foreach item in array array['preview-plasma','preview-boreal','preview-pearl','preview-volcano','preview-atlantis','preview-sakura','preview-toxic','preview-onyx','preview-supernova','preview-neon-ocean'] loop
  if not public.box_style_allowed(owner_id,'name',item) or not public.box_style_allowed(owner_id,'frame',item) then raise exception 'Owner cannot use %',item; end if;
  perform public.set_pass_styles(item,item);
 end loop;
 foreach item in array array['preview-teko','preview-oxanium','preview-chakra','preview-exo','preview-satisfy','preview-marck','preview-gothic','preview-graduate','preview-londrina','preview-faster'] loop
  if not public.username_font_allowed(owner_id,item) then raise exception 'Owner cannot use %',item; end if;
  perform public.set_username_font(item);
 end loop;
 if public.username_font_for('jrlescovar')<>'preview-faster' then raise exception 'Owner font not visible'; end if;
 perform set_config('request.jwt.claim.sub',other_auth::text,true);
 if public.username_font_for('jrlescovar')<>'normal' then raise exception 'Private font exposed to other user'; end if;
 if public.box_style_allowed(owner_id,'name','preview-plasma') or public.box_style_allowed(owner_id,'frame','preview-plasma') then raise exception 'Private style exposed to other user'; end if;
 if public.username_font_allowed(other_id,'preview-teko') or public.box_style_allowed(other_id,'name','preview-plasma') then raise exception 'Other user allowed to equip preview'; end if;
 begin
  perform public.set_username_font('preview-teko');
  raise exception 'Unexpected private font write' using errcode='ZX001';
 exception when raise_exception then null;
 end;
 begin
  perform public.set_pass_styles('preview-plasma','preview-plasma');
  raise exception 'Unexpected private style write' using errcode='ZX001';
 exception when raise_exception then null;
 end;
 if exists(select 1 from public.box_style_catalog where style like 'preview-%') then raise exception 'Private items leaked into loot catalog'; end if;
end;$$;
rollback;
