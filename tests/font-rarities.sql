begin;
create or replace function public.box_random_index(p_count integer) returns integer language plpgsql volatile as $$
declare desired text:=current_setting('qa.font');tier text;draw integer;
begin
 select rarity into tier from public.box_style_catalog where style=desired;
 if p_count=100 then return case tier when 'epic' then 70 when 'mythic' then 85 else 95 end;end if;
 select pos into draw from (select c.style,k.kind,(row_number() over(order by c.style,k.kind)-1)::integer pos from public.box_style_catalog c cross join(values('name'),('frame'),('font'))k(kind) where c.rarity=tier and ((c.item_kind is null and k.kind in('name','frame'))or c.item_kind=k.kind))pool where style=desired and kind='font';
 return draw;
end $$;
do $$
declare target uuid;subject uuid;font text;result jsonb;expected text;reward integer;
begin
 select p.id,v.auth_user_id into target,subject from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id=1000002;
 perform set_config('request.jwt.claim.sub',subject::text,true);
 insert into public.box_balances(profile_id,balance)values(target,3) on conflict(profile_id)do update set balance=3;
 foreach font in array array['bebasneue','amaticsc','kalam']loop
 perform set_config('qa.font',font,true);
 result:=public.open_box(gen_random_uuid());
 expected:=case font when 'bebasneue' then 'epic' else 'mythic' end;
 reward:=case font when 'bebasneue' then 100 else 250 end;
 if result->>'style'<>font or result->>'kind'<>'font' or result->>'rarity'<>expected or (result->>'xpAwarded')::integer<>reward or not(result->>'duplicate')::boolean then raise exception 'Wrong font rarity/reward: %',result;end if;
 end loop;
end $$;
rollback;
select 'Bebas Neue epic/100 XP and Amatic SC/Kalam mythic/250 XP drops verified; rolled back' as result;
