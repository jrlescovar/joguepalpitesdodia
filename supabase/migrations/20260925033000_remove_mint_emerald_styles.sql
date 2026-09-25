begin;

update public.public_profiles set pass_name_style = 'none', updated_at = now()
where pass_name_style in ('mint-deep-blue','emerald-cyan');
update public.public_profiles set pass_border_style = 'none', updated_at = now()
where pass_border_style in ('mint-deep-blue','emerald-cyan');

alter table public.public_profiles drop constraint if exists pass_name_style_check;
alter table public.public_profiles add constraint pass_name_style_check
  check (pass_name_style in ('none','gold','blood','monochrome','purple','green','light-blue','dark-blue','orange','pink','sunset','flame','ember','rose-purple','midnight-electric','green-gold','lilac-silver','wine-rose','ice-blue','navy-pink','graphite-silver','rainbow','aurora','royal-sapphire','sunset-ocean','neon-circuit','coral-lilac'));

alter table public.public_profiles drop constraint if exists pass_border_style_check;
alter table public.public_profiles add constraint pass_border_style_check
  check (pass_border_style in ('none','gold','blood','monochrome','purple','green','light-blue','dark-blue','orange','pink','sunset','flame','ember','rose-purple','midnight-electric','green-gold','lilac-silver','wine-rose','ice-blue','navy-pink','graphite-silver','rainbow','aurora','royal-sapphire','sunset-ocean','neon-circuit','coral-lilac'));

create or replace function public.set_pass_styles(p_border_style text,p_name_style text)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare target uuid;
begin
  target := public.own_profile_id();
  if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
  if not public.pass_active(target) then raise exception 'A assinatura precisa estar ativa para personalizar o perfil.'; end if;
  if p_border_style is null or p_border_style not in ('none','gold','blood','monochrome','purple','green','light-blue','dark-blue','orange','pink','sunset','flame','ember','rose-purple','midnight-electric','green-gold','lilac-silver','wine-rose','ice-blue','navy-pink','graphite-silver','rainbow','aurora','royal-sapphire','sunset-ocean','neon-circuit','coral-lilac')
    or p_name_style is null or p_name_style not in ('none','gold','blood','monochrome','purple','green','light-blue','dark-blue','orange','pink','sunset','flame','ember','rose-purple','midnight-electric','green-gold','lilac-silver','wine-rose','ice-blue','navy-pink','graphite-silver','rainbow','aurora','royal-sapphire','sunset-ocean','neon-circuit','coral-lilac') then
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
