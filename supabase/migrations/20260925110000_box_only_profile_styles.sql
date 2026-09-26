-- A assinatura concede caixas, mas estilos de nome e moldura dependem do inventário.
create or replace function public.box_style_allowed(p_profile_id uuid,p_kind text,p_style text)
returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
  select p_style = 'none'
    or exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001)
    or exists(select 1 from public.box_inventory i where i.profile_id=p_profile_id and i.kind=p_kind and i.style=p_style);
$$;
revoke execute on function public.box_style_allowed(uuid,text,text) from public,anon,authenticated;

-- Remove seleções herdadas do Premium quando o jogador não ganhou o item.
update public.public_profiles p
set pass_name_style = case
      when p.pass_name_style <> 'none' and not exists (
        select 1 from public.box_inventory i
        where i.profile_id=p.id and i.kind='name' and i.style=p.pass_name_style
      ) then 'none' else p.pass_name_style end,
    pass_border_style = case
      when p.pass_border_style <> 'none' and not exists (
        select 1 from public.box_inventory i
        where i.profile_id=p.id and i.kind='frame' and i.style=p.pass_border_style
      ) then 'none' else p.pass_border_style end,
    updated_at = now()
where p.player_id <> 1000001
  and (
    (p.pass_name_style <> 'none' and not exists (
      select 1 from public.box_inventory i
      where i.profile_id=p.id and i.kind='name' and i.style=p.pass_name_style
    ))
    or (p.pass_border_style <> 'none' and not exists (
      select 1 from public.box_inventory i
      where i.profile_id=p.id and i.kind='frame' and i.style=p.pass_border_style
    ))
  );

notify pgrst, 'reload schema';
