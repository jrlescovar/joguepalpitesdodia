begin;

alter table public.box_style_catalog add column theme text not null default 'classic'
  check(theme in ('classic','halloween'));
alter table public.box_style_catalog drop constraint box_style_catalog_item_kind_check;
alter table public.box_style_catalog add constraint box_style_catalog_item_kind_check
  check(item_kind is null or item_kind in ('font','background'));
alter table public.box_inventory drop constraint box_inventory_kind_check;
alter table public.box_inventory add constraint box_inventory_kind_check
  check(kind in ('name','frame','font','background'));
alter table public.box_openings drop constraint box_openings_kind_check;
alter table public.box_openings add constraint box_openings_kind_check
  check(kind in ('name','frame','font','background'));

insert into public.box_style_catalog(style,rarity,item_kind,theme) values
 ('halloween-pumpkin','rare',null,'halloween'),
 ('halloween-bloodmoon','epic',null,'halloween'),
 ('halloween-mist','mythic',null,'halloween'),
 ('eater','epic','font','halloween'),
 ('butcherman','mythic','font','halloween'),
 ('halloween-house','common','background','halloween'),
 ('halloween-graveyard','rare','background','halloween'),
 ('halloween-bats','legendary','background','halloween');

-- Extend the existing accepted colors without changing their permissions.
alter table public.public_profiles drop constraint pass_name_style_check;
alter table public.public_profiles add constraint pass_name_style_check check (
 pass_name_style in ('none','gold','blood','purple','green','dark-blue','orange','pink','sunset','ember','rose-purple','midnight-electric','green-gold','lilac-silver','wine-rose','ice-blue','navy-pink','graphite-silver','rainbow','royal-sapphire','sunset-ocean','neon-circuit','coral-lilac','legend-nebula','legend-abyss','legend-prism','legend-solar','myth-petroleum-bronze','myth-burgundy-sand','myth-cerulean-rust','myth-plum-copper','myth-jade-mauve','myth-olive-rose-graphite','myth-fuchsia-petroleum','rare-plum-beige','legend-ruby-eclipse','halloween-pumpkin','halloween-bloodmoon','halloween-mist'));
alter table public.public_profiles drop constraint pass_border_style_check;
alter table public.public_profiles add constraint pass_border_style_check check (
 pass_border_style in ('none','gold','blood','purple','green','dark-blue','orange','pink','sunset','ember','rose-purple','midnight-electric','green-gold','lilac-silver','wine-rose','ice-blue','navy-pink','graphite-silver','rainbow','royal-sapphire','sunset-ocean','neon-circuit','coral-lilac','legend-nebula','legend-abyss','legend-prism','legend-solar','myth-petroleum-bronze','myth-burgundy-sand','myth-cerulean-rust','myth-plum-copper','myth-jade-mauve','myth-olive-rose-graphite','myth-fuchsia-petroleum','rare-plum-beige','legend-ruby-eclipse','halloween-pumpkin','halloween-bloodmoon','halloween-mist'));

alter table public.public_profiles add column profile_background_style text not null default 'none'
 check(profile_background_style in ('none','halloween-house','halloween-graveyard','halloween-bats'));

create function public.get_profile_background(p_profile_id uuid) returns text
 language sql stable security definer set search_path=public,auth,pg_temp as $$
 select case when auth.uid() is not null and
   (p.profile_background_style='none' or exists(
    select 1 from public.box_inventory i where i.profile_id=p.id and i.kind='background' and i.style=p.profile_background_style
   )) then p.profile_background_style else 'none' end
 from public.public_profiles p where p.id=p_profile_id;
$$;
revoke all on function public.get_profile_background(uuid) from public,anon,authenticated;
grant execute on function public.get_profile_background(uuid) to authenticated;

create function public.set_profile_background(p_style text) returns text
 language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id();
begin
 if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
 if p_style is null or (p_style<>'none' and not exists(
  select 1 from public.box_inventory i join public.box_style_catalog c on c.style=i.style
  where i.profile_id=target and i.kind='background' and i.style=p_style and c.item_kind='background'
 )) then raise exception 'Fundo ainda não desbloqueado.'; end if;
 update public.public_profiles set profile_background_style=p_style,updated_at=now() where id=target;
 return p_style;
end;$$;
revoke all on function public.set_profile_background(text) from public,anon,authenticated;
grant execute on function public.set_profile_background(text) to authenticated;

-- Both boxes spend the same existing balance. Keep each catalog separate.
do $$
declare base_definition text;
begin
 base_definition:=pg_get_functiondef('public.open_box(uuid)'::regprocedure);
 if position('where c.rarity=selected_rarity' in base_definition)=0 then
  raise exception 'Unexpected open_box definition; Halloween boxes were not installed.';
 end if;
 execute replace(base_definition,'where c.rarity=selected_rarity',
  'where c.rarity=selected_rarity and c.theme=''classic''');
 execute replace(replace(base_definition,'public.open_box(', 'public.open_halloween_box('),
  'where c.rarity=selected_rarity',
  'where c.rarity=selected_rarity and c.theme=''halloween''');
end;$$;
revoke all on function public.open_halloween_box(uuid) from public,anon,authenticated;
grant execute on function public.open_halloween_box(uuid) to authenticated;

-- Give the owner every item in the collection, without equipping or changing XP.
insert into public.box_inventory(profile_id,kind,style)
 select p.id,k.kind,c.style from public.public_profiles p
 cross join public.box_style_catalog c
 cross join lateral (select unnest(case when c.item_kind is null then array['name','frame'] else array[c.item_kind] end) as kind) k
 where p.player_id=1000001 and c.theme='halloween'
 on conflict do nothing;

notify pgrst, 'reload schema';
commit;
