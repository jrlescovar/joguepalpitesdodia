begin;

create table public.paid_tournaments (
  id uuid primary key,
  name text not null check (length(name) between 5 and 120),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  entry_cents integer not null check (entry_cents > 0),
  prize_cents integer not null check (prize_cents > 0),
  prediction_count integer not null default 21 check (prediction_count = 21),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  check (ends_at = starts_at + interval '3 days')
);
insert into public.paid_tournaments(id,name,starts_at,ends_at,entry_cents,prize_cents)
values ('36b34446-4dcf-4d63-8cf3-5ba8ec8d1113','Torneio de Finalização',
 '2026-10-04T00:00:00-03:00','2026-10-07T00:00:00-03:00',267,2500);

alter table public.infinitepay_orders add column tournament_id uuid references public.paid_tournaments(id);
alter table public.infinitepay_orders drop constraint infinitepay_orders_kind_check;
alter table public.infinitepay_orders add constraint infinitepay_orders_kind_check
 check (kind in ('classic','halloween','font','supporter','tournament'));
alter table public.infinitepay_orders drop constraint infinitepay_orders_check;
alter table public.infinitepay_orders add constraint infinitepay_orders_check check (
 (kind='classic' and ((quantity=3 and amount_cents=321) or (quantity=7 and amount_cents=567) or (quantity=11 and amount_cents=917)))
 or (kind='halloween' and ((quantity=2 and amount_cents=321) or (quantity=6 and amount_cents=567) or (quantity=10 and amount_cents=917)))
 or (kind='font' and ((quantity=1 and amount_cents=321) or (quantity=3 and amount_cents=567) or (quantity=5 and amount_cents=917)))
 or (kind='supporter' and quantity=1 and amount_cents=497)
 or (kind='tournament' and quantity=1 and amount_cents>0)
);
alter table public.infinitepay_orders add constraint infinitepay_order_tournament_target check (
 (kind='tournament' and tournament_id is not null) or (kind<>'tournament' and tournament_id is null)
);
create index infinitepay_tournament_orders on public.infinitepay_orders(profile_id,tournament_id) where kind='tournament';

create table public.paid_tournament_entries (
 tournament_id uuid not null references public.paid_tournaments(id),
 profile_id uuid not null references public.public_profiles(id) on delete cascade,
 order_id uuid not null unique references public.infinitepay_orders(id),
 correct_answers integer not null default 0 check (correct_answers between 0 and 21),
 registered_at timestamptz not null default now(),
 primary key(tournament_id,profile_id)
);
create index paid_tournament_ranking on public.paid_tournament_entries(tournament_id,correct_answers desc,registered_at,profile_id);
alter table public.paid_tournaments enable row level security;
alter table public.paid_tournament_entries enable row level security;
revoke all on public.paid_tournaments,public.paid_tournament_entries from public,anon,authenticated;
grant select,insert,update on public.paid_tournaments,public.paid_tournament_entries to service_role;

-- This read never marks a player as enrolled. Only verified payment can do that.
create function public.get_finishing_tournament(p_tournament_id uuid default null)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare tournament public.paid_tournaments; viewer uuid := public.own_profile_id();
 enrolled boolean; players jsonb := '[]'::jsonb; own_rank jsonb; participants integer;
begin
 if viewer is null then raise exception 'Entre na sua conta e crie seu perfil.'; end if;
 select * into tournament from public.paid_tournaments
 where enabled and (p_tournament_id is null or id=p_tournament_id) order by created_at desc limit 1;
 if not found then return null; end if;
 enrolled := exists(select 1 from public.paid_tournament_entries where tournament_id=tournament.id and profile_id=viewer);
 select count(*)::integer into participants from public.paid_tournament_entries where tournament_id=tournament.id;
 if enrolled then
  -- Positions only order the display. Equal hit totals share the first-place prize.
  with ranked as materialized (
   select e.*,row_number() over(order by e.correct_answers desc,e.registered_at,p.player_id)::integer as position
   from public.paid_tournament_entries e join public.public_profiles p on p.id=e.profile_id
   where e.tournament_id=tournament.id
  ), visible as materialized (
   select r.profile_id,r.position,public.get_public_profile(r.profile_id)
    || jsonb_build_object('position',r.position,'correctAnswers',r.correct_answers) as player
   from ranked r where r.position<=10 or r.profile_id=viewer
  ) select coalesce(jsonb_agg(player order by position) filter(where position<=10),'[]'::jsonb),
   (jsonb_agg(player) filter(where profile_id=viewer))->0 into players,own_rank from visible;
 end if;
 return jsonb_build_object(
  'id',tournament.id,'name',tournament.name,'startsAt',tournament.starts_at,'endsAt',tournament.ends_at,
  'entryCents',tournament.entry_cents,'prizeCents',tournament.prize_cents,'predictionCount',tournament.prediction_count,
  'serverTime',floor(extract(epoch from now())*1000)::bigint,
  'enrolled',enrolled,'registrationOpen',not enrolled and now()<tournament.starts_at,
  'participants',participants,'players',players,'ownRank',own_rank,
  -- The initial screen deliberately has no fabricated tournament predictions.
  'predictions','[]'::jsonb
 );
end;
$$;
revoke all on function public.get_finishing_tournament(uuid) from public,anon,authenticated;
grant execute on function public.get_finishing_tournament(uuid) to authenticated;

create function public.reserve_tournament_order(p_profile_id uuid,p_request_id uuid,p_handle text,p_tournament_id uuid)
returns public.infinitepay_orders language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare tournament public.paid_tournaments; saved public.infinitepay_orders;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'Acesso negado.'; end if;
 if p_request_id is null or p_handle is null or p_handle !~ '^[a-zA-Z0-9_-]{1,80}$' then raise exception 'Pedido inválido.'; end if;
 perform 1 from public.public_profiles where id=p_profile_id for update;
 if not found then raise exception 'Perfil não encontrado.'; end if;
 select * into tournament from public.paid_tournaments where id=p_tournament_id and enabled for share;
 if not found then raise exception 'Torneio não encontrado.'; end if;
 if now()>=tournament.starts_at then raise exception 'As inscrições deste torneio já encerraram.'; end if;
 if exists(select 1 from public.paid_tournament_entries where tournament_id=p_tournament_id and profile_id=p_profile_id) then
  raise exception 'Você já está inscrito neste torneio.';
 end if;
 select * into saved from public.infinitepay_orders where profile_id=p_profile_id and request_id=p_request_id;
 if found then
  if saved.kind<>'tournament' or saved.tournament_id is distinct from p_tournament_id or saved.handle<>p_handle then raise exception 'Pedido inválido.'; end if;
  return saved;
 end if;
 -- Reuse an unpaid order even across tabs, so a player cannot buy entry twice.
 select * into saved from public.infinitepay_orders where profile_id=p_profile_id and tournament_id=p_tournament_id
  and kind='tournament' and paid_at is null order by created_at desc limit 1;
 if found then return saved; end if;
 if (select count(*) from public.infinitepay_orders where profile_id=p_profile_id and created_at>now()-interval '1 hour')>=20 then
  raise exception 'Muitas tentativas de pagamento. Aguarde um pouco.';
 end if;
 insert into public.infinitepay_orders(profile_id,request_id,handle,kind,quantity,amount_cents,tournament_id)
 values(p_profile_id,p_request_id,p_handle,'tournament',1,tournament.entry_cents,p_tournament_id) returning * into saved;
 return saved;
end;
$$;
revoke all on function public.reserve_tournament_order(uuid,uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.reserve_tournament_order(uuid,uuid,text,uuid) to service_role;

create or replace function public.settle_infinitepay_order(p_order_id uuid,p_transaction_nsu text,p_invoice_slug text,p_amount_cents integer,p_capture_method text)
returns boolean language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare purchase public.infinitepay_orders; tournament public.paid_tournaments;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'Acesso negado.'; end if;
 if nullif(p_transaction_nsu,'') is null or nullif(p_invoice_slug,'') is null or p_capture_method is null or p_capture_method not in ('pix','credit_card') then raise exception 'Pagamento inválido.'; end if;
 select * into purchase from public.infinitepay_orders where id=p_order_id for update;
 if not found or p_amount_cents is distinct from purchase.amount_cents then raise exception 'Pagamento inválido.'; end if;
 if purchase.paid_at is not null then
  if purchase.transaction_nsu is distinct from p_transaction_nsu or purchase.invoice_slug is distinct from p_invoice_slug then raise exception 'Pagamento já confirmado com outra transação.'; end if;
  return true;
 end if;
 perform 1 from public.public_profiles where id=purchase.profile_id for update;
 if not found then raise exception 'Perfil não encontrado.'; end if;
 if purchase.kind='tournament' then
  select * into tournament from public.paid_tournaments where id=purchase.tournament_id;
  if not found or purchase.quantity<>1 or purchase.amount_cents<>tournament.entry_cents or purchase.created_at>=tournament.starts_at then raise exception 'Inscrição inválida.'; end if;
 end if;
 update public.infinitepay_orders set transaction_nsu=p_transaction_nsu,invoice_slug=p_invoice_slug,capture_method=p_capture_method,paid_at=now() where id=p_order_id;
 case purchase.kind
  when 'tournament' then
   -- A delayed webhook still honors a verified order made before the start.
   insert into public.paid_tournament_entries(tournament_id,profile_id,order_id)
   values(purchase.tournament_id,purchase.profile_id,purchase.id) on conflict(tournament_id,profile_id) do nothing;
  when 'classic' then
   insert into public.box_balances(profile_id,balance) values(purchase.profile_id,purchase.quantity)
   on conflict(profile_id) do update set balance=public.box_balances.balance+purchase.quantity;
  when 'font' then
   insert into public.font_box_balances(profile_id,balance) values(purchase.profile_id,purchase.quantity)
   on conflict(profile_id) do update set balance=public.font_box_balances.balance+purchase.quantity;
  when 'halloween' then
   insert into public.halloween_box_balances(profile_id,balance) values(purchase.profile_id,purchase.quantity)
   on conflict(profile_id) do update set balance=public.halloween_box_balances.balance+purchase.quantity;
  when 'supporter' then
   insert into public.pass_prepaid_payments(stripe_session_id,profile_id) values('ip_'||purchase.id::text,purchase.profile_id);
   insert into public.pass_prepaid(profile_id,ends_at) values(purchase.profile_id,now()+interval '30 days')
   on conflict(profile_id) do update set ends_at=greatest(now(),public.pass_prepaid.ends_at)+interval '30 days',updated_at=now();
 end case;
 return true;
end;
$$;
revoke all on function public.settle_infinitepay_order(uuid,text,text,integer,text) from public,anon,authenticated;
grant execute on function public.settle_infinitepay_order(uuid,text,text,integer,text) to service_role;
notify pgrst,'reload schema';
commit;
