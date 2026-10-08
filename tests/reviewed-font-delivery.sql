begin;
create temporary table reviewed_font_expectations(style text,rarity text,theme text) on commit drop;
insert into reviewed_font_expectations values
 ('rubikglitch','mythic','classic'),
 ('rubikwetpaint','mythic','classic'),
 ('rubikdirt','epic','classic'),
 ('rampartone','mythic','classic'),
 ('tiltprism','mythic','classic'),
 ('shojumaru','epic','classic'),
 ('tradewinds','epic','classic'),
 ('sedgwickavedisplay','legendary','classic'),
 ('fugazone','rare','classic'),
 ('reggaeone','epic','classic'),
 ('akronim','mythic','classic'),
 ('alfaslabone','rare','classic'),
 ('allertastencil','epic','classic'),
 ('arbutus','rare','classic'),
 ('arizonia','legendary','classic'),
 ('barrio','epic','classic'),
 ('bigelowrules','mythic','classic'),
 ('bungeeshade','epic','classic'),
 ('caesardressing','mythic','halloween'),
 ('kiranghaerang','mythic','classic'),
 ('fascinateinline','mythic','classic'),
 ('fingerpaint','mythic','classic'),
 ('frederickathegreat','mythic','halloween'),
 ('hennypenny','legendary','halloween'),
 ('lacquer','epic','classic'),
 ('rubikbeastly','epic','classic'),
 ('rubikmoonrocks','epic','halloween'),
 ('ewert','epic','halloween'),
 ('sancreek','mythic','classic'),
 ('megrim','mythic','classic'),
 ('geostarfill','epic','classic'),
 ('kumaroneoutline','mythic','classic'),
 ('miltoniantattoo','rare','classic'),
 ('rubikvinyl','legendary','halloween');

-- The first random call chooses rarity, the next chooses its sorted item.
create or replace function public.box_random_index(p_count integer) returns integer
language plpgsql volatile security definer set search_path=public,pg_temp as $$
begin
 if current_setting('test.release_next_roll',true)='true' then
  perform set_config('test.release_next_roll','false',true);
  return current_setting('test.release_roll')::integer;
 end if;
 return current_setting('test.release_index')::integer;
end;$$;

do $$
declare target uuid; target_auth uuid; owner_id uuid; owner_auth uuid; target_name text;
 font record; route text; routes text[]; pool_index integer; roll integer; reward integer;
 request uuid; first_result jsonb; duplicate_result jsonb; balances_before integer[]; balances_after integer[];
 retired text;
begin
 select p.id,v.auth_user_id,p.username into strict target,target_auth,target_name
  from public.public_profiles p join public.private_profiles v on v.profile_id=p.id
  where p.player_id<>1000001 and v.auth_user_id is not null order by p.player_id limit 1;
 select p.id,v.auth_user_id into strict owner_id,owner_auth from public.public_profiles p
  join public.private_profiles v on v.profile_id=p.id where p.player_id=1000001;
 perform set_config('request.jwt.claim.sub',target_auth::text,true);
 perform public.set_username_font('normal');
 insert into public.box_balances(profile_id,balance) values(target,200) on conflict(profile_id) do update set balance=200;
 insert into public.font_box_balances(profile_id,balance) values(target,200) on conflict(profile_id) do update set balance=200;
 insert into public.halloween_box_balances(profile_id,balance) values(target,200) on conflict(profile_id) do update set balance=200;

 for font in select * from reviewed_font_expectations order by style loop
  if not exists(select 1 from public.box_style_catalog c where c.style=font.style and c.rarity=font.rarity and c.theme=font.theme and c.item_kind='font') then raise exception 'Wrong font catalog %',font.style; end if;
  routes:=case when font.theme='halloween' then array['halloween'] else array['classic','font'] end;
  foreach route in array routes loop
   perform set_config('request.jwt.claim.sub',target_auth::text,true);
   perform public.set_username_font('normal');
   delete from public.box_inventory where profile_id=target and style=font.style and kind='font';
   if public.username_font_allowed(target,font.style) then raise exception 'Unowned font allowed %',font.style; end if;
   begin
    perform public.set_username_font(font.style);
    raise exception 'Unowned font equipped';
   exception when raise_exception then
    if sqlerrm<>'Fonte indisponível para esta conta.' then raise; end if;
   end;
   select position into strict pool_index from (
    select c.style,k.kind,(row_number() over(order by c.style,k.kind)-1)::integer position
    from public.box_style_catalog c cross join (values ('name'),('frame'),('font')) k(kind)
    where c.rarity=font.rarity and c.theme=case when route='halloween' then 'halloween' else 'classic' end
     and (route<>'font' or c.item_kind='font')
     and ((c.item_kind is null and k.kind in ('name','frame')) or c.item_kind=k.kind)
   ) pool where style=font.style and kind='font';
   roll:=case when route='halloween' then case font.rarity when 'epic' then 0 when 'mythic' then 60 else 90 end
    when route='font' then case font.rarity when 'rare' then 0 when 'epic' then 45 when 'mythic' then 80 else 95 end
    else case font.rarity when 'rare' then 40 when 'epic' then 70 when 'mythic' then 85 else 95 end end;
   reward:=case font.rarity when 'rare' then 50 when 'epic' then 100 when 'mythic' then 250 else 500 end;
   perform set_config('test.release_roll',roll::text,true);
   perform set_config('test.release_index',pool_index::text,true);
   perform set_config('test.release_next_roll','true',true);
   balances_before:=array[(select balance from public.box_balances where profile_id=target),(select balance from public.font_box_balances where profile_id=target),(select balance from public.halloween_box_balances where profile_id=target)];
   request:=gen_random_uuid();
   first_result:=case route when 'font' then public.open_font_box(request) when 'halloween' then public.open_halloween_box(request) else public.open_box(request) end;
   if first_result->>'style'<>font.style or first_result->>'kind'<>'font' or first_result->>'rarity'<>font.rarity or (first_result->>'duplicate')::boolean then raise exception 'Wrong delivery % %',route,font.style; end if;
   if first_result is distinct from (case route when 'font' then public.open_font_box(request) when 'halloween' then public.open_halloween_box(request) else public.open_box(request) end) then raise exception 'Non-idempotent opening'; end if;
   if public.set_username_font(font.style)->>'usernameFont'<>font.style then raise exception 'Won font cannot be equipped'; end if;
   perform set_config('request.jwt.claim.sub',owner_auth::text,true);
   if public.username_font_for(target_name)<>font.style or public.get_public_profile(target)->>'usernameFont'<>font.style then raise exception 'Won public font was masked'; end if;
   perform set_config('request.jwt.claim.sub',target_auth::text,true);
   perform set_config('test.release_next_roll','true',true);
   request:=gen_random_uuid();
   duplicate_result:=case route when 'font' then public.open_font_box(request) when 'halloween' then public.open_halloween_box(request) else public.open_box(request) end;
   if not(duplicate_result->>'duplicate')::boolean or (duplicate_result->>'xpAwarded')::integer<>reward then raise exception 'Incorrect duplicate reward %',font.style; end if;
   balances_after:=array[(select balance from public.box_balances where profile_id=target),(select balance from public.font_box_balances where profile_id=target),(select balance from public.halloween_box_balances where profile_id=target)];
   balances_before[case route when 'classic' then 1 when 'font' then 2 else 3 end]:=balances_before[case route when 'classic' then 1 when 'font' then 2 else 3 end]-2;
   if balances_before is distinct from balances_after then raise exception 'Wrong box balance %',route; end if;
  end loop;
 end loop;
 foreach retired in array array['preview-diplomatasc','preview-yatraone','preview-asset','preview-biorhymeexpanded','preview-bokor','preview-bowlbyonesc','preview-changaone','preview-diplomata','preview-geostar','preview-rubikspraypaint'] loop
  perform set_config('request.jwt.claim.sub',owner_auth::text,true);
  if public.username_font_allowed(owner_id,retired) or exists(select 1 from public.box_style_catalog where style=retired) then raise exception 'Retired font still available %',retired; end if;
  begin
   update public.public_profiles set username_font=retired where id=owner_id;
   raise exception 'Retired font bypassed constraint';
  exception when check_violation then null; end;
 end loop;
 if not exists(select 1 from public.box_style_catalog where style='bebasneue' and rarity='rare') then raise exception 'Bebas Neue rarity incorrect'; end if;
 if exists(select 1 from public.box_style_catalog where style='preview-rubikpuddles') then raise exception 'Private preview entered loot pool'; end if;
end;$$;
rollback;
