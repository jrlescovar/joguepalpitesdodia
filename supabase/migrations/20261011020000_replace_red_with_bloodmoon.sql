begin;
-- Retire Red and convert existing ownership/equipment to the event equivalent.
-- Keep the catalog record for historical openings; retired items are outside loot pools.
lock table public.public_profiles,public.box_inventory,public.box_style_catalog,public.player_mail,public.box_openings in share row exclusive mode;
do $$begin
 if not exists(select 1 from public.box_style_catalog where style='blood' and theme='classic' and item_kind is null)
 or not exists(select 1 from public.box_style_catalog where style='halloween-bloodmoon' and theme='halloween' and item_kind is null) then
  raise exception 'Unexpected Red or Lua Sangrenta catalog';
 end if;
end $$;
create temporary table red_replacement_expected on commit drop as
 select profile_id,kind,min(acquired_at) acquired_at from (
  select profile_id,kind,acquired_at from public.box_inventory where style='blood' and kind in ('name','frame')
  union all select id,'name',now() from public.public_profiles where pass_name_style='blood'
  union all select id,'frame',now() from public.public_profiles where pass_border_style='blood'
 ) recipients group by profile_id,kind;
create temporary table red_replacement_profiles_before on commit drop as select * from public.public_profiles;
create temporary table red_replacement_other_inventory on commit drop as
 select * from public.box_inventory where style<>'blood';
create temporary table red_replacement_history_before on commit drop as
 select count(*) count,md5(coalesce(string_agg(to_jsonb(o)::text,'' order by id),'')) digest from public.box_openings o;

insert into public.box_inventory(profile_id,kind,style,acquired_at)
 select profile_id,kind,'halloween-bloodmoon',acquired_at from red_replacement_expected on conflict do nothing;
update public.public_profiles set
 pass_name_style=case when pass_name_style='blood' then 'halloween-bloodmoon' else pass_name_style end,
 pass_border_style=case when pass_border_style='blood' then 'halloween-bloodmoon' else pass_border_style end
 where pass_name_style='blood' or pass_border_style='blood';
delete from public.box_inventory where style='blood' and kind in ('name','frame');
-- Pending deliveries retain their original expiry, including any existing equivalent.
update public.player_mail existing set created_at=least(existing.created_at,old.created_at)
 from public.player_mail old where old.style='blood' and existing.style='halloween-bloodmoon'
 and existing.profile_id=old.profile_id and existing.kind=old.kind;
delete from public.player_mail old where old.style='blood' and exists(
 select 1 from public.player_mail existing where existing.style='halloween-bloodmoon' and existing.profile_id=old.profile_id and existing.kind=old.kind);
update public.player_mail set style='halloween-bloodmoon' where style='blood';
update public.box_style_catalog set theme='retired' where style='blood';
alter table public.public_profiles add constraint retired_red_name check(pass_name_style<>'blood');
alter table public.public_profiles add constraint retired_red_frame check(pass_border_style<>'blood');
alter table public.box_inventory add constraint retired_red_inventory check(style<>'blood');
alter table public.player_mail add constraint retired_red_mail check(style is distinct from 'blood');
-- Reject the removed style even for the owner, while preserving all other rules.
do $$declare definition text; revised text;begin
 definition:=pg_get_functiondef('public.box_style_allowed(uuid,text,text)'::regprocedure);
 revised:=replace(definition,'select case when p_style in','select case when p_style=''blood'' then false when p_style in');
 if definition=revised then raise exception 'Expected style permission guard not found';end if;
 execute revised;
 definition:=pg_get_functiondef('public.admin_grant_frame_mail(uuid,text)'::regprocedure);
 revised:=replace(definition,'where style=p_style and (item_kind','where style=p_style and theme<>''retired'' and (item_kind');
 if definition=revised then raise exception 'Expected mail style validation not found';end if;
 execute revised;
end $$;

do $$begin
 if exists(select 1 from red_replacement_expected r where not exists(select 1 from public.box_inventory i where i.profile_id=r.profile_id and i.kind=r.kind and i.style='halloween-bloodmoon')) then raise exception 'An owner lost their replacement';end if;
 if exists(select 1 from red_replacement_profiles_before b join public.public_profiles p using(id)
 where p.pass_name_style<>case when b.pass_name_style='blood' then 'halloween-bloodmoon' else b.pass_name_style end
 or p.pass_border_style<>case when b.pass_border_style='blood' then 'halloween-bloodmoon' else b.pass_border_style end
 or (to_jsonb(p)-'pass_name_style'-'pass_border_style')<>(to_jsonb(b)-'pass_name_style'-'pass_border_style')) then raise exception 'Unexpected profile or equipment changes';end if;
 if exists(select * from red_replacement_other_inventory except select * from public.box_inventory) then raise exception 'Unrelated inventory changed';end if;
 if exists(select 1 from public.box_inventory where style='blood') or exists(select 1 from public.public_profiles where pass_name_style='blood' or pass_border_style='blood') then raise exception 'Red remains active';end if;
 if (select row(count(*),md5(coalesce(string_agg(to_jsonb(o)::text,'' order by id),''))) from public.box_openings o)<>(select row(count,digest) from red_replacement_history_before) then raise exception 'Opening history changed';end if;
 if exists(select 1 from public.public_profiles p where public.box_style_allowed(p.id,'name','blood') or public.box_style_allowed(p.id,'frame','blood')) then raise exception 'Removed style still allowed';end if;
end $$;
notify pgrst,'reload schema';
commit;
select jsonb_build_object('redEquipped',(select count(*) from public.public_profiles where pass_name_style='blood' or pass_border_style='blood'),
 'redInventory',(select count(*) from public.box_inventory where style='blood'),
 'redTheme',(select theme from public.box_style_catalog where style='blood'),
 'historicalRedOpenings',(select count(*) from public.box_openings where style='blood')) red_replacement_report;
