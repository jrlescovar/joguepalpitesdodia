begin;
create table public.level_drops(id uuid primary key default gen_random_uuid(),profile_id uuid not null references public.public_profiles(id),milestone integer not null check(milestone>0 and milestone%5=0),tier integer not null default 0 check(tier between 0 and 4),clicks_left integer not null default 5 check(clicks_left between 0 and 5),status text not null default 'playing' check(status in ('playing','ready','claimed')),reward jsonb,created_at timestamptz not null default now(),unique(profile_id,milestone));
create table public.level_drop_requests(profile_id uuid not null references public.public_profiles(id),request_id uuid not null,response jsonb not null,primary key(profile_id,request_id));
alter table public.level_drops enable row level security;
alter table public.level_drop_requests enable row level security;
revoke all on public.level_drops,public.level_drop_requests from anon,authenticated;
create or replace function public.get_level_drops() returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); lvl integer;
begin
 select level into lvl from public.public_profiles where id=target and player_id=1000001 and lower(username)='zaotips';
 if lvl is null then raise exception 'Drops em teste exclusivo para zaotips.'; end if;
 insert into public.level_drops(profile_id,milestone) select target,n from generate_series(5,(lvl/5)*5,5) n on conflict(profile_id,milestone) do nothing;
 return jsonb_build_object('level',lvl,'drops',coalesce((select jsonb_agg(to_jsonb(d) order by milestone) from public.level_drops d where profile_id=target),'[]'::jsonb));
end $$;
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
  if d.tier<4 and public.box_random_index(100)<(array[15,10,7,4])[d.tier+1] then
   update public.level_drops set tier=tier+1,clicks_left=5 where id=d.id returning * into d;
  else
   update public.level_drops set clicks_left=clicks_left-1,status=case when clicks_left=1 then 'ready' else 'playing' end where id=d.id returning * into d;
  end if;
 end if;
 response:=to_jsonb(d);
 insert into public.level_drop_requests(profile_id,request_id,response) values(target,p_request_id,response);
 return response;
end $$;
revoke all on function public.get_level_drops(),public.interact_level_drop(uuid,uuid,boolean) from public,anon;
grant execute on function public.get_level_drops(),public.interact_level_drop(uuid,uuid,boolean) to authenticated;
notify pgrst,'reload schema';
commit;
select count(*) functions_created from pg_proc where pronamespace='public'::regnamespace and proname in ('get_level_drops','interact_level_drop');
