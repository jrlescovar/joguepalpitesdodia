begin;
create table public.player_mail(id uuid primary key default gen_random_uuid(),profile_id uuid not null references public.public_profiles(id),kind text not null check(kind in ('drop','classic','font','halloween','premium')),quantity integer not null check(quantity>0),granted_by uuid,received_at timestamptz,created_at timestamptz not null default now(),delivery_key text unique);
alter table public.player_mail enable row level security;
revoke all on public.player_mail from public,anon,authenticated;
alter table public.level_drops drop constraint level_drops_milestone_check;
alter table public.level_drops add constraint level_drops_milestone_check check(milestone>=0 and milestone%5=0);
alter table public.level_drops drop constraint level_drops_profile_id_milestone_key;
create unique index level_drop_milestone_unique on public.level_drops(profile_id,milestone) where milestone>0;
create or replace function public.get_level_drops() returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); lvl integer;
begin
 select level into lvl from public.public_profiles where id=target and player_id=1000001 and lower(username)='zaotips';
 if lvl is null then raise exception 'Drops em teste exclusivo para zaotips.'; end if;
 insert into public.level_drops(profile_id,milestone) select target,n from generate_series(5,(lvl/5)*5,5)n on conflict(profile_id,milestone) where milestone>0 do nothing;
 return jsonb_build_object('level',lvl,'drops',coalesce((select jsonb_agg(to_jsonb(d) order by created_at,milestone) from public.level_drops d where profile_id=target),'[]'::jsonb));
end $$;
create function public.get_mailbox() returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); result jsonb; levels integer:=0;
begin
 if target is null then raise exception 'Perfil não encontrado.'; end if;
 if exists(select 1 from public.public_profiles where id=target and player_id=1000001 and lower(username)='zaotips') then
  perform public.get_level_drops();
  select count(*) into levels from public.level_drops where profile_id=target and received_at is null and status<>'claimed';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('kind',kind,'quantity',quantity) order by kind),'[]'::jsonb) into result from
 (select kind,sum(quantity)::integer quantity from (select kind,quantity from public.player_mail where profile_id=target and received_at is null union all select 'drop',levels where levels>0)all_rewards group by kind)groups;
 return result;
end $$;
create function public.receive_mail(p_kind text) returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); quantity integer; sender uuid; balance_table text;
begin
 perform 1 from public.public_profiles where id=target for update;
 if not found then raise exception 'Perfil não encontrado.'; end if;
 with received as (update public.player_mail set received_at=now() where profile_id=target and kind=p_kind and received_at is null returning *) select coalesce(sum(r.quantity),0)::integer,(array_agg(r.granted_by))[1] into quantity,sender from received r;
 if p_kind='drop' then
  if not exists(select 1 from public.public_profiles where id=target and player_id=1000001) then raise exception 'Drop em prévia exclusiva.'; end if;
  update public.level_drops set received_at=now() where profile_id=target and received_at is null and status<>'claimed';
  insert into public.level_drops(profile_id,milestone,received_at) select target,0,now() from generate_series(1,quantity);
 elsif p_kind in ('classic','font','halloween') then
  balance_table:=case p_kind when 'classic' then 'box_balances' when 'font' then 'font_box_balances' else 'halloween_box_balances' end;
  if quantity>0 then execute format('insert into public.%I(profile_id,balance) values($1,$2) on conflict(profile_id) do update set balance=public.%I.balance+excluded.balance',balance_table,balance_table) using target,quantity; end if;
 elsif p_kind='premium' then
  if quantity>0 then insert into public.pass_grants(profile_id,grant_ends_at,granted_by) values(target,now()+make_interval(days=>quantity),sender) on conflict(profile_id) do update set grant_ends_at=greatest(now(),public.pass_grants.grant_ends_at)+make_interval(days=>quantity),revoked_at=null,granted_by=excluded.granted_by,updated_at=now(); end if;
 else raise exception 'Entrega inválida.'; end if;
end $$;
create or replace function public.admin_grant_boxes(p_profile_id uuid,p_quantity integer) returns integer language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare balance integer;
begin
 if not public.is_admin() then raise exception 'Somente admin pode enviar recompensas.'; end if;
 if p_quantity is null or p_quantity<1 or p_quantity>100 then raise exception 'Informe de 1 a 100.'; end if;
 insert into public.player_mail(profile_id,kind,quantity,granted_by) values(p_profile_id,'classic',p_quantity,auth.uid());
 select b.balance into balance from public.box_balances b where profile_id=p_profile_id;
 return coalesce(balance,0);
end $$;
create or replace function public.admin_grant_font_boxes(p_profile_id uuid,p_quantity integer) returns integer language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare balance integer;
begin
 if not public.is_admin() then raise exception 'Somente admin pode enviar recompensas.'; end if;
 if p_quantity is null or p_quantity<1 or p_quantity>100 then raise exception 'Informe de 1 a 100.'; end if;
 insert into public.player_mail(profile_id,kind,quantity,granted_by) values(p_profile_id,'font',p_quantity,auth.uid());
 select b.balance into balance from public.font_box_balances b where profile_id=p_profile_id;
 return coalesce(balance,0);
end $$;
create or replace function public.admin_grant_halloween_boxes(p_profile_id uuid,p_quantity integer) returns integer language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare balance integer;
begin
 if not public.is_admin() then raise exception 'Somente admin pode enviar recompensas.'; end if;
 if p_quantity is null or p_quantity<1 or p_quantity>100 then raise exception 'Informe de 1 a 100.'; end if;
 insert into public.player_mail(profile_id,kind,quantity,granted_by) values(p_profile_id,'halloween',p_quantity,auth.uid());
 select b.balance into balance from public.halloween_box_balances b where profile_id=p_profile_id;
 return coalesce(balance,0);
end $$;
create or replace function public.admin_set_pass_grant(p_profile_id uuid,p_days integer) returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
 if not public.is_admin() then raise exception 'Somente admin pode alterar Premium.'; end if;
 if p_days is null or p_days<0 or p_days>3650 then raise exception 'Prazo inválido.'; end if;
 if p_days=0 then
  update public.pass_grants set revoked_at=now(),updated_at=now() where profile_id=p_profile_id;
  update public.player_mail set received_at=now() where profile_id=p_profile_id and kind='premium' and received_at is null;
 else insert into public.player_mail(profile_id,kind,quantity,granted_by) values(p_profile_id,'premium',p_days,auth.uid()); end if;
 return public.admin_get_pass_grant(p_profile_id);
end $$;
revoke all on function public.get_mailbox(),public.receive_mail(text) from public,anon;
grant execute on function public.get_mailbox(),public.receive_mail(text) to authenticated;
insert into public.player_mail(profile_id,kind,quantity,delivery_key) values('4325ba8c-8b6b-9635-429c-cef8c63ac2d4','drop',1,'zaotips-test-drop-20261009') on conflict(delivery_key) do nothing;
notify pgrst,'reload schema';
commit;
select 'Mail delivery ready; 1 drop sent to zaotips' result;
