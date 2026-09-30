begin;

-- Preserve opening history and ownership records, but remove Orange from new draws.
update public.box_style_catalog set theme = 'retired' where style = 'orange';

-- An equipped retired style must no longer be visible on the player's profile.
update public.public_profiles
set pass_name_style = case when pass_name_style = 'orange' then 'none' else pass_name_style end,
    pass_border_style = case when pass_border_style = 'orange' then 'none' else pass_border_style end,
    updated_at = now()
where pass_name_style = 'orange' or pass_border_style = 'orange';

create or replace function public.box_style_allowed(p_profile_id uuid,p_kind text,p_style text)
returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
  select p_style = 'none'
    or (p_style <> 'orange' and (
      exists(select 1 from public.public_profiles p where p.id=p_profile_id and p.player_id=1000001)
      or exists(select 1 from public.box_inventory i where i.profile_id=p_profile_id and i.kind=p_kind and i.style=p_style)
    ));
$$;
revoke execute on function public.box_style_allowed(uuid,text,text) from public,anon,authenticated;

create or replace function public.get_box_state()
returns jsonb language sql stable security definer set search_path=public,auth,pg_temp as $$
  select jsonb_build_object(
    'balance',coalesce((select b.balance from public.box_balances b where b.profile_id=public.own_profile_id()),0),
    'inventory',coalesce((select jsonb_agg(jsonb_build_object('kind',i.kind,'style',i.style,'rarity',c.rarity) order by i.acquired_at)
      from public.box_inventory i join public.box_style_catalog c on c.style=i.style
      where i.profile_id=public.own_profile_id() and i.style <> 'orange'),'[]'::jsonb)
  );
$$;
revoke execute on function public.get_box_state() from public,anon,authenticated;
grant execute on function public.get_box_state() to authenticated;

commit;
