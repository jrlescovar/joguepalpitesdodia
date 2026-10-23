begin;
-- Each tier gets five attempts. Conditional failure masses are
-- 50/100, 28/50, 15/22 and 5/7, giving final odds 50/28/15/5/2.
create or replace function public.level_drop_upgrade_chance(p_tier integer)
returns double precision language sql immutable set search_path=public,pg_temp as $$
 select case when p_tier between 0 and 3 then
  1-power((array[0.5::double precision,0.28/0.50,0.15/0.22,0.05/0.07])[p_tier+1],0.2::double precision)
 else 0::double precision end;
$$;
revoke all on function public.level_drop_upgrade_chance(integer) from public,anon,authenticated;
create or replace function public.interact_level_drop(p_drop_id uuid,p_request_id uuid,p_open boolean default false) returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id();d public.level_drops%rowtype; prior jsonb;rar text;choice record;owned boolean;xp_reward integer:=0;progress integer[];player record;opening uuid;response jsonb;
begin
 if p_request_id is null then raise exception 'Identificador obrigatório.'; end if;
 select * into player from public.public_profiles where id=target and player_id=1000001 and lower(username)='zaotips' for update;
 if not found then raise exception 'Drops em teste exclusivo para zaotips.'; end if;
 select r.response into prior from public.level_drop_requests r where profile_id=target and request_id=p_request_id;
 if prior is not null then return prior; end if;
 select * into d from public.level_drops where id=p_drop_id and profile_id=target for update;
 if not found then raise exception 'Drop não encontrado.'; end if;
 if d.status='claimed' then return to_jsonb(d); end if;
 if p_open then
  if d.status<>'ready' then raise exception 'Conclua os cliques antes de abrir.'; end if;
  rar:=(array['common','rare','epic','mythic','legendary'])[d.tier+1];
  select c.style,k.kind into choice from public.box_style_catalog c cross join (values ('name'),('frame'),('font')) k(kind) where c.theme='classic' and c.rarity=rar and ((c.item_kind is null and k.kind in ('name','frame')) or c.item_kind=k.kind) order by random() limit 1;
  if not found then raise exception 'Nenhum item disponível nesta raridade.'; end if;
  owned:=exists(select 1 from public.box_inventory where profile_id=target and kind=choice.kind and style=choice.style);
  if owned then
   xp_reward:=case rar when 'common' then 25 when 'rare' then 50 when 'epic' then 100 when 'mythic' then 250 else 500 end;
   progress:=public.award_xp(player.level,player.xp,xp_reward);
   update public.public_profiles set level=progress[1],xp=progress[2],updated_at=now() where id=target;
  else insert into public.box_inventory(profile_id,kind,style) values(target,choice.kind,choice.style); end if;
  insert into public.box_openings(profile_id,request_id,kind,style,rarity,duplicate,xp_awarded) values(target,d.id,choice.kind,choice.style,rar,owned,xp_reward) returning id into opening;
  update public.level_drops set status='claimed',reward=jsonb_build_object('id',opening,'kind',choice.kind,'style',choice.style,'rarity',rar,'duplicate',owned,'xpAwarded',xp_reward,'balance',0) where id=d.id returning * into d;
 else
  if d.status<>'playing' then raise exception 'Este drop já pode ser aberto.'; end if;
  if d.tier<4 and (('x'||substr(replace(gen_random_uuid()::text,'-',''),1,8))::bit(32)::bigint / 4294967296.0) < public.level_drop_upgrade_chance(d.tier) then
   update public.level_drops set tier=tier+1,clicks_left=5 where id=d.id returning * into d;
  else
   update public.level_drops set clicks_left=clicks_left-1,status=case when clicks_left=1 then 'ready' else 'playing' end where id=d.id returning * into d;
  end if;
 end if;
 response:=to_jsonb(d);
 insert into public.level_drop_requests(profile_id,request_id,response) values(target,p_request_id,response);
 return response;
end $$;
notify pgrst,'reload schema';
commit;
select 'Final drop odds updated' result;
