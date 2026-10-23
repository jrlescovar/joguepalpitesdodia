-- Release level drops for all players and deliver retroactive milestones once.
begin;
create or replace function public.get_level_drops() returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); lvl integer;
begin
 select level into lvl from public.public_profiles where id=target;
 if lvl is null then raise exception 'Perfil não encontrado.'; end if;
 insert into public.level_drops(profile_id,milestone) select target,n from generate_series(5,(lvl/5)*5,5)n on conflict(profile_id,milestone) where milestone>0 do nothing;
 return jsonb_build_object('level',lvl,'drops',coalesce((select jsonb_agg(to_jsonb(d) order by created_at,milestone) from public.level_drops d where profile_id=target),'[]'::jsonb));
end $$;
create or replace function public.get_mailbox() returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); result jsonb; levels integer:=0;
begin
 if target is null then raise exception 'Perfil não encontrado.'; end if;
  perform public.get_level_drops();
  select count(*) into levels from public.level_drops where profile_id=target and received_at is null and status<>'claimed';
 select coalesce(jsonb_agg(jsonb_build_object('kind',kind,'quantity',quantity) order by kind),'[]'::jsonb) into result from
 (select kind,sum(quantity)::integer quantity from (select kind,quantity from public.player_mail where profile_id=target and received_at is null union all select 'drop',levels where levels>0)all_rewards group by kind)groups;
 return result;
end $$;

-- Preserve the current opening, odds, XP and replay behavior; remove only preview gates.
do $$
declare definition text; revised text; signature text;
begin
 signature:='public.interact_level_drop(uuid,uuid,boolean)';
 definition:=pg_get_functiondef(signature::regprocedure);
 revised:=replace(definition,'where id=target and player_id=1000001 and lower(username)=''zaotips'' for update','where id=target for update');
 if revised=definition then raise exception 'Expected interaction preview gate not found'; end if;
 revised:=replace(revised,'Drops em teste exclusivo para zaotips.','Perfil não encontrado.');
 execute revised;
 signature:='public.receive_mail(text)';
 definition:=pg_get_functiondef(signature::regprocedure);
 revised:=replace(definition,'if not exists(select 1 from public.public_profiles where id=target and player_id=1000001) then raise exception ''Drop em prévia exclusiva.''; end if;','perform public.get_level_drops();');
 if revised=definition then raise exception 'Expected mail preview gate not found'; end if;
 execute revised;
 foreach signature in array array['public.receive_level_drop(uuid)','public.receive_all_level_drops()'] loop
  definition:=pg_get_functiondef(signature::regprocedure);
  revised:=replace(definition,'if not exists(select 1 from public.public_profiles where id=target and player_id=1000001 and lower(username)=''zaotips'') then raise exception ''Prévia exclusiva do zaotips.''; end if;','if target is null then raise exception ''Perfil não encontrado.''; end if;');
  if revised=definition then raise exception 'Expected legacy preview gate not found: %',signature; end if;
  execute revised;
 end loop;
end $$;

-- Existing claimed or received milestones remain untouched.
insert into public.level_drops(profile_id,milestone)
select p.id,n from public.public_profiles p
cross join lateral generate_series(5,(p.level/5)*5,5)n
on conflict(profile_id,milestone) where milestone>0 do nothing;

-- Gift delivery key prevents accidental duplicate sends.
insert into public.player_mail(profile_id,kind,quantity,delivery_key)
select id,'drop',100,'zaotips-100-drops-20261009' from public.public_profiles
where player_id=1000001 and lower(username)='zaotips'
on conflict(delivery_key) do nothing;
do $$ begin
 if not exists(select 1 from public.player_mail where delivery_key='zaotips-100-drops-20261009' and quantity=100 and profile_id='4325ba8c-8b6b-9635-429c-cef8c63ac2d4') then
  raise exception 'Zaotips gift delivery could not be verified';
 end if;
end $$;
notify pgrst,'reload schema';
commit;
select jsonb_build_object(
 'players',count(*),'eligiblePlayers',count(*) filter(where level>=5),
 'levelMilestones',sum(level/5),
 'pendingLevelDrops',(select count(*) from public.level_drops where milestone>0 and received_at is null and status<>'claimed'),
 'playersWithPendingLevelDrops',(select count(distinct profile_id) from public.level_drops where milestone>0 and received_at is null and status<>'claimed'),
 'zaotipsExtraDrops',(select quantity from public.player_mail where delivery_key='zaotips-100-drops-20261009'),
 'zaotipsGiftPending',(select received_at is null from public.player_mail where delivery_key='zaotips-100-drops-20261009')
) delivery_report from public.public_profiles;
