begin;
create table public.font_box_balances (
 profile_id uuid primary key references public.public_profiles(id) on delete cascade,
 balance integer not null default 0 check(balance>=0)
);
alter table public.font_box_balances enable row level security;
revoke all on public.font_box_balances from public,anon,authenticated;


create table public.font_box_purchases (
  stripe_session_id text primary key check (stripe_session_id like 'cs_%'),
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  quantity integer not null,
  amount_cents integer not null,
  paid_at timestamptz not null default now(),
  check ((quantity = 1 and amount_cents = 321) or (quantity = 3 and amount_cents = 567))
);
alter table public.font_box_purchases enable row level security;
revoke all on public.font_box_purchases from public, anon, authenticated;

create or replace function public.credit_font_box_purchase(p_profile_id uuid, p_session_id text, p_quantity integer, p_amount_cents integer)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_profile_id is null or p_session_id is null or p_session_id not like 'cs_%'
     or p_quantity is null or p_amount_cents is null
     or not ((p_quantity = 1 and p_amount_cents = 321) or (p_quantity = 3 and p_amount_cents = 567)) then
    raise exception 'Compra de caixas inválida.';
  end if;
  insert into public.font_box_purchases(stripe_session_id,profile_id,quantity,amount_cents)
    values(p_session_id,p_profile_id,p_quantity,p_amount_cents) on conflict do nothing;
  if found then
    insert into public.font_box_balances(profile_id,balance) values(p_profile_id,p_quantity)
      on conflict(profile_id) do update set balance=public.font_box_balances.balance+p_quantity;
  end if;
end;
$$;
revoke execute on function public.credit_font_box_purchase(uuid,text,integer,integer) from public, anon, authenticated;
grant execute on function public.credit_font_box_purchase(uuid,text,integer,integer) to service_role;

-- Reuse the audited transactional opening flow with its own balance and pool.
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.open_box(uuid)'::regprocedure);
 if position('when roll < 40' in definition)=0 or position('c.theme=''classic''' in definition)=0 then
  raise exception 'Unexpected classic opening definition';
 end if;
 definition:=replace(definition,'public.open_box(', 'public.open_font_box(');
 definition:=replace(definition,'public.box_balances','public.font_box_balances');
 definition:=replace(definition,'c.theme=''classic''','c.theme=''classic'' and c.item_kind=''font''');
 definition:=replace(definition,
  'case when roll < 40 then ''common'' when roll < 70 then ''rare'' when roll < 85 then ''epic'' when roll < 95 then ''mythic'' else ''legendary'' end',
  'case when roll < 45 then ''rare'' when roll < 80 then ''epic'' when roll < 95 then ''mythic'' else ''legendary'' end');
 execute definition;
end;$$;
revoke all on function public.open_font_box(uuid) from public,anon,authenticated;
grant execute on function public.open_font_box(uuid) to authenticated;

create function public.get_font_box_state() returns jsonb
language sql stable security definer set search_path=public,auth,pg_temp as $$
 select jsonb_build_object(
  'balance',coalesce((select balance from public.font_box_balances where profile_id=public.own_profile_id()),0),
  'inventory',coalesce((select jsonb_agg(jsonb_build_object('kind',i.kind,'style',i.style,'rarity',c.rarity) order by i.acquired_at)
   from public.box_inventory i join public.box_style_catalog c on c.style=i.style
   where i.profile_id=public.own_profile_id() and c.theme='classic' and i.kind='font'),'[]'::jsonb));
$$;
revoke all on function public.get_font_box_state() from public,anon,authenticated;
grant execute on function public.get_font_box_state() to authenticated;
notify pgrst,'reload schema';
commit;
