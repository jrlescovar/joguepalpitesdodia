begin;

create table public.halloween_box_grants (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  quantity integer not null check (quantity between 1 and 100),
  granted_by uuid not null,
  granted_at timestamptz not null default now()
);
alter table public.halloween_box_grants enable row level security;
revoke all on public.halloween_box_grants from public, anon, authenticated;

create function public.admin_get_halloween_box_balance(p_profile_id uuid)
returns integer language plpgsql stable security definer set search_path=public,auth,pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode consultar caixas.'; end if;
  if not exists(select 1 from public.public_profiles where id=p_profile_id) then raise exception 'Jogador não encontrado.'; end if;
  return coalesce((select balance from public.halloween_box_balances where profile_id=p_profile_id),0);
end;
$$;
revoke all on function public.admin_get_halloween_box_balance(uuid) from public,anon,authenticated;
grant execute on function public.admin_get_halloween_box_balance(uuid) to authenticated;

create function public.admin_grant_halloween_boxes(p_profile_id uuid,p_quantity integer)
returns integer language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare new_balance integer;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode conceder caixas.'; end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 100 then raise exception 'Informe de 1 a 100 caixas.'; end if;
  if not exists(select 1 from public.public_profiles where id=p_profile_id) then raise exception 'Jogador não encontrado.'; end if;
  insert into public.halloween_box_balances(profile_id,balance) values(p_profile_id,p_quantity)
    on conflict(profile_id) do update set balance=public.halloween_box_balances.balance+excluded.balance
    returning balance into new_balance;
  insert into public.halloween_box_grants(profile_id,quantity,granted_by) values(p_profile_id,p_quantity,auth.uid());
  return new_balance;
end;
$$;
revoke all on function public.admin_grant_halloween_boxes(uuid,integer) from public,anon,authenticated;
grant execute on function public.admin_grant_halloween_boxes(uuid,integer) to authenticated;
notify pgrst,'reload schema';
commit;
