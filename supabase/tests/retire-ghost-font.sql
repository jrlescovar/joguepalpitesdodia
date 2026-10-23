-- Execute after the retirement migration, inside the same rolled-back test.
do $$declare player record;denied boolean;begin
 if exists(select 1 from public.public_profiles where username_font in ('rubikvinyl','preview-rubikvinyl'))
  or exists(select 1 from public.box_inventory where kind='font' and style in ('rubikvinyl','preview-rubikvinyl'))
  or exists(select 1 from public.box_style_catalog where theme<>'retired' and item_kind='font' and style in ('rubikvinyl','preview-rubikvinyl')) then raise exception 'Ghost still available';end if;
 for player in select p.id,v.auth_user_id,b.data from ghost_profiles_before b join public.public_profiles p using(id)
  left join public.private_profiles v on v.profile_id=p.id loop
  if player.data->>'username_font' in ('rubikvinyl','preview-rubikvinyl') then
   if (select username_font from public.public_profiles where id=player.id)<>'normal'
    or (select to_jsonb(p)-'username_font'-'updated_at' from public.public_profiles p where id=player.id)<>player.data-'username_font'-'updated_at'
     then raise exception 'Font reset modified other player data';end if;
   denied:=false;
   begin update public.public_profiles set username_font='rubikvinyl' where id=player.id; exception when check_violation then denied:=true;end;
   if not denied then raise exception 'Retired font constraint missing';end if;
  elsif (select to_jsonb(p) from public.public_profiles p where id=player.id)<>player.data then raise exception 'Unrelated profile modified';end if;
  if public.username_font_allowed(player.id,'rubikvinyl') or public.username_font_allowed(player.id,'preview-rubikvinyl') then raise exception 'Ghost can be equipped';end if;
 end loop;
 if exists(select 1 from ghost_openings_before b full join public.box_openings o using(id) where b.data is distinct from to_jsonb(o)) then raise exception 'Opening receipt modified';end if;
 if exists(select 1 from ghost_inventory_before b full join public.box_inventory i using(profile_id,kind,style)
  where b.style not in ('rubikvinyl','preview-rubikvinyl') and b.data is distinct from to_jsonb(i)) then raise exception 'Other item modified';end if;
end;$$;
select 'PASS: Ghost removed; active profiles reset; re-equip rejected; XP and other profile data intact; other inventory and opening receipts intact' as result;
