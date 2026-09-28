begin;
-- Deterministic draws only inside this rollback transaction.
create or replace function public.box_random_index(p_count integer) returns integer language sql volatile as $$ select case when p_count=100 then 99 else 0 end; $$;
do $$
declare target uuid;subject uuid;other uuid;other_subject uuid;font text;item jsonb;again jsonb;request uuid:=gen_random_uuid();before_style text;
begin
 select p.id,v.auth_user_id into target,subject from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id=1000002;
 if target is null then raise exception 'Player 1000002 missing';end if;
 if (select count(*) from public.box_inventory where profile_id=target and kind='font')<>5 then raise exception 'Missing granted fonts';end if;
 perform set_config('request.jwt.claim.sub',subject::text,true);
 foreach font in array array['monocraft','dancingscript','bebasneue','amaticsc','kalam'] loop
 perform public.set_username_font(font);
 if public.get_public_profile(target)->>'usernameFont'<>font then raise exception 'Public font mismatch';end if;
 end loop;
 select p.id,v.auth_user_id into other,other_subject from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id not in (1000001,1000002) order by p.player_id limit 1;
 perform set_config('request.jwt.claim.sub',other_subject::text,true);
 delete from public.box_inventory where profile_id=other and kind='font';
 begin perform public.set_username_font('amaticsc');raise exception 'Locked font accepted';exception when raise_exception then if SQLERRM<>'Fonte indisponível para esta conta.' then raise;end if;end;
 insert into public.box_balances(profile_id,balance) values(other,2) on conflict(profile_id) do update set balance=2;
 select pass_name_style into before_style from public.public_profiles where id=other;
 item:=public.open_box(request);
 if item->>'kind'<>'font' or item->>'style'<>'amaticsc' or item->>'rarity'<>'legendary' or (item->>'duplicate')::boolean or (item->>'balance')::int<>1 then raise exception 'Wrong font reward: %',item;end if;
 again:=public.open_box(request);
 if again<>item then raise exception 'Idempotence failed';end if;
 perform public.set_username_font('amaticsc');
 if public.get_public_profile(other)->>'usernameFont'<>'amaticsc' then raise exception 'Unlocked font invisible';end if;
 if (select pass_name_style from public.public_profiles where id=other)<>before_style then raise exception 'Font changed color';end if;
 item:=public.open_box(gen_random_uuid());
 if not (item->>'duplicate')::boolean or (item->>'xpAwarded')::int<>500 or (item->>'balance')::int<>0 then raise exception 'Duplicate failed: %',item;end if;
 if has_function_privilege('anon','public.set_username_font(text)','execute') or has_function_privilege('authenticated','public.username_font_allowed(uuid,text)','execute') then raise exception 'Wrong grants';end if;
end $$;
rollback;
select 'Five grants, font equip/public visibility, locked access, legendary drop, idempotence and duplicate 500 XP OK; rolled back' as result;
