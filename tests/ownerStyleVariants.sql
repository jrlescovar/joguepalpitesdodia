begin;
do $$ declare owner_id uuid; other_id uuid; variant_style text; styles text[]:=array['lab-blue-4-rose-quartz','lab-blue-4-polar-amber','lab-blue-4-tourmaline','lab-blue-4-glacial-opal','lab-blue-4-garnet','lab-blue-4-vivid-topaz','lab-blue-4-obsidian','lab-blue-6-violet-haze','lab-blue-6-coral-cloud','lab-blue-6-emerald-veil','lab-blue-6-daybreak','lab-blue-6-golden-mirage','lab-blue-6-crimson-silk','lab-blue-6-moonlight','lab-blue-7-acid-pulse','lab-blue-7-ruby-laser','lab-blue-7-lilac-code','lab-blue-7-solar-pixel','lab-blue-7-turquoise-beat','lab-blue-7-pink-tuning','lab-blue-7-white-signal','lab-blue-9-copper-orbit','lab-blue-9-green-comet','lab-blue-9-magenta-satellite','lab-blue-9-gravity','lab-blue-9-meteorite','lab-blue-9-amber-cosmos','lab-blue-9-crimson-star','lab-blue-10-red-aurora','lab-blue-10-jade-sky','lab-blue-10-borealis','lab-blue-10-pink-horizon','lab-blue-10-tropical-light','lab-blue-10-indigo-vortex','lab-blue-10-golden-galaxy'];
begin
 select id into strict owner_id from public.public_profiles where player_id=1000001;
 select id into strict other_id from public.public_profiles where player_id<>1000001 order by player_id limit 1;
 foreach variant_style in array styles loop
  if not public.box_style_allowed(owner_id,'name',variant_style) or not public.box_style_allowed(owner_id,'frame',variant_style) then raise exception 'Owner cannot use %',variant_style; end if;
  if public.box_style_allowed(other_id,'name',variant_style) or public.box_style_allowed(other_id,'frame',variant_style) then raise exception 'Other player can use %',variant_style; end if;
  if public.box_style_allowed(owner_id,'font',variant_style) then raise exception 'Color accepted as font %',variant_style; end if;
  update public.public_profiles set pass_name_style=variant_style,pass_border_style=variant_style where id=owner_id;
  begin
   update public.public_profiles set pass_name_style=variant_style where id=other_id;
   raise exception 'Other player bypassed name check';
  exception when check_violation then null; end;
  begin
   update public.public_profiles set pass_border_style=variant_style where id=other_id;
   raise exception 'Other player bypassed frame check';
  exception when check_violation then null; end;
  if exists(select 1 from public.box_style_catalog where box_style_catalog.style=variant_style) then raise exception 'Variant entered loot pool %',variant_style; end if;
 end loop;
 if public.box_style_allowed(owner_id,'name','lab-blue-1') or public.box_style_allowed(owner_id,'frame','lab-blue-4-unknown') then raise exception 'Unknown variant allowed'; end if;
 if not public.box_style_allowed(owner_id,'name','lab-blue-10') or not public.box_style_allowed(owner_id,'frame','lab-blue-4') then raise exception 'Existing previews unavailable'; end if;
end; $$;
rollback;
