begin;

create table public.font_box_grants (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  quantity integer not null check (quantity between 1 and 100),
  granted_by uuid not null,
  granted_at timestamptz not null default now()
);
alter table public.font_box_grants enable row level security;
revoke all on public.font_box_grants from public, anon, authenticated;

create function public.admin_get_font_box_balance(p_profile_id uuid)
returns integer language plpgsql stable security definer set search_path=public,auth,pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode consultar caixas.'; end if;
  if not exists(select 1 from public.public_profiles where id=p_profile_id) then raise exception 'Jogador não encontrado.'; end if;
  return coalesce((select balance from public.font_box_balances where profile_id=p_profile_id),0);
end;
$$;
revoke all on function public.admin_get_font_box_balance(uuid) from public,anon,authenticated;
grant execute on function public.admin_get_font_box_balance(uuid) to authenticated;

create function public.admin_grant_font_boxes(p_profile_id uuid,p_quantity integer)
returns integer language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare new_balance integer;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode conceder caixas.'; end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 100 then raise exception 'Informe de 1 a 100 caixas.'; end if;
  if not exists(select 1 from public.public_profiles where id=p_profile_id) then raise exception 'Jogador não encontrado.'; end if;
  insert into public.font_box_balances(profile_id,balance) values(p_profile_id,p_quantity)
    on conflict(profile_id) do update set balance=public.font_box_balances.balance+excluded.balance
    returning balance into new_balance;
  insert into public.font_box_grants(profile_id,quantity,granted_by) values(p_profile_id,p_quantity,auth.uid());
  return new_balance;
end;
$$;
revoke all on function public.admin_grant_font_boxes(uuid,integer) from public,anon,authenticated;
grant execute on function public.admin_grant_font_boxes(uuid,integer) to authenticated;
-- Extend the existing style checks, preserving every previously valid style.
do $$ declare constraint_row record; begin
 for constraint_row in select conname,pg_get_constraintdef(oid) definition from pg_constraint where conrelid='public.public_profiles'::regclass and contype='c' and (conname like '%pass_name_style%' or conname like '%pass_border_style%') loop
  execute format('alter table public.public_profiles drop constraint %I',constraint_row.conname);
  execute format('alter table public.public_profiles add constraint %I check ((%s) or (%I in (''lab-blue-1'',''lab-blue-2'',''lab-blue-3'',''lab-blue-4'',''lab-blue-5'',''lab-blue-6'',''lab-blue-7'',''lab-blue-8'',''lab-blue-9'',''lab-blue-10'')))',constraint_row.conname,substring(constraint_row.definition from 8 for length(constraint_row.definition)-8),case when constraint_row.conname like '%name%' then 'pass_name_style' else 'pass_border_style' end);
 end loop;
end; $$;
do $$ declare definition text; begin
 definition:=pg_get_functiondef('public.box_style_allowed(uuid,text,text)'::regprocedure);
 definition:=replace(definition,'select p_style=', 'select (left(p_style,9)<>''lab-blue-'' or exists(select 1 from public.public_profiles where id=p_profile_id and player_id=1000001)) and (p_style=');
 definition:=replace(definition,'));', ')));');
 execute definition;
end; $$;
notify pgrst,'reload schema';
commit;
