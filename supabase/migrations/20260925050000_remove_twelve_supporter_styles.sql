begin;

update public.public_profiles
set pass_name_style = case pass_name_style
  when 'rare-olive-rose' then 'myth-olive-rose-graphite'
  when 'monochrome' then 'graphite-silver'
  when 'light-blue' then 'ice-blue'
  when 'flame' then 'sunset'
  when 'myth-slate-tangerine' then 'myth-cerulean-rust'
  when 'aurora' then 'neon-circuit'
  when 'legend-cosmos' then 'legend-nebula'
  when 'myth-indigo-mustard' then 'royal-sapphire'
  when 'rare-sand-sage' then 'myth-jade-mauve'
  when 'rare-mustard-slate' then 'royal-sapphire'
  when 'rare-terracotta-ivory' then 'myth-cerulean-rust'
  when 'myth-carmine-sage' then 'wine-rose'
end
where pass_name_style in ('rare-olive-rose','monochrome','light-blue','flame','myth-slate-tangerine','aurora','legend-cosmos','myth-indigo-mustard','rare-sand-sage','rare-mustard-slate','rare-terracotta-ivory','myth-carmine-sage');

update public.public_profiles
set pass_border_style = case pass_border_style
  when 'rare-olive-rose' then 'myth-olive-rose-graphite'
  when 'monochrome' then 'graphite-silver'
  when 'light-blue' then 'ice-blue'
  when 'flame' then 'sunset'
  when 'myth-slate-tangerine' then 'myth-cerulean-rust'
  when 'aurora' then 'neon-circuit'
  when 'legend-cosmos' then 'legend-nebula'
  when 'myth-indigo-mustard' then 'royal-sapphire'
  when 'rare-sand-sage' then 'myth-jade-mauve'
  when 'rare-mustard-slate' then 'royal-sapphire'
  when 'rare-terracotta-ivory' then 'myth-cerulean-rust'
  when 'myth-carmine-sage' then 'wine-rose'
end
where pass_border_style in ('rare-olive-rose','monochrome','light-blue','flame','myth-slate-tangerine','aurora','legend-cosmos','myth-indigo-mustard','rare-sand-sage','rare-mustard-slate','rare-terracotta-ivory','myth-carmine-sage');


alter table public.public_profiles drop constraint if exists pass_name_style_check;
alter table public.public_profiles add constraint pass_name_style_check
  check (pass_name_style in ('none','gold','blood','purple','green','dark-blue','orange','pink','sunset','ember','rose-purple','midnight-electric','green-gold','lilac-silver','wine-rose','ice-blue','navy-pink','graphite-silver','rainbow','royal-sapphire','sunset-ocean','neon-circuit','coral-lilac','legend-nebula','legend-abyss','legend-prism','legend-solar','myth-petroleum-bronze','myth-burgundy-sand','myth-cerulean-rust','myth-plum-copper','myth-jade-mauve','myth-olive-rose-graphite','myth-fuchsia-petroleum','rare-plum-beige','legend-ruby-eclipse'));

alter table public.public_profiles drop constraint if exists pass_border_style_check;
alter table public.public_profiles add constraint pass_border_style_check
  check (pass_border_style in ('none','gold','blood','purple','green','dark-blue','orange','pink','sunset','ember','rose-purple','midnight-electric','green-gold','lilac-silver','wine-rose','ice-blue','navy-pink','graphite-silver','rainbow','royal-sapphire','sunset-ocean','neon-circuit','coral-lilac','legend-nebula','legend-abyss','legend-prism','legend-solar','myth-petroleum-bronze','myth-burgundy-sand','myth-cerulean-rust','myth-plum-copper','myth-jade-mauve','myth-olive-rose-graphite','myth-fuchsia-petroleum','rare-plum-beige','legend-ruby-eclipse'));

create or replace function public.set_pass_styles(p_border_style text,p_name_style text)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid;
begin
  target := public.own_profile_id();
  if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
  if not public.pass_active(target) then raise exception 'A assinatura precisa estar ativa para personalizar o perfil.'; end if;
  if p_border_style is null or p_border_style not in ('none','gold','blood','purple','green','dark-blue','orange','pink','sunset','ember','rose-purple','midnight-electric','green-gold','lilac-silver','wine-rose','ice-blue','navy-pink','graphite-silver','rainbow','royal-sapphire','sunset-ocean','neon-circuit','coral-lilac','legend-nebula','legend-abyss','legend-prism','legend-solar','myth-petroleum-bronze','myth-burgundy-sand','myth-cerulean-rust','myth-plum-copper','myth-jade-mauve','myth-olive-rose-graphite','myth-fuchsia-petroleum','rare-plum-beige','legend-ruby-eclipse')
    or p_name_style is null or p_name_style not in ('none','gold','blood','purple','green','dark-blue','orange','pink','sunset','ember','rose-purple','midnight-electric','green-gold','lilac-silver','wine-rose','ice-blue','navy-pink','graphite-silver','rainbow','royal-sapphire','sunset-ocean','neon-circuit','coral-lilac','legend-nebula','legend-abyss','legend-prism','legend-solar','myth-petroleum-bronze','myth-burgundy-sand','myth-cerulean-rust','myth-plum-copper','myth-jade-mauve','myth-olive-rose-graphite','myth-fuchsia-petroleum','rare-plum-beige','legend-ruby-eclipse') then
    raise exception 'Escolha um estilo disponível.';
  end if;
  update public.public_profiles set pass_border_style = p_border_style,
    pass_name_style = p_name_style, updated_at = now() where id = target;
  return public.get_pass_status();
end;
$$;
revoke execute on function public.set_pass_styles(text,text) from public, anon, authenticated;
grant execute on function public.set_pass_styles(text,text) to authenticated;

commit;
