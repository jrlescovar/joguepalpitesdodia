begin;

-- Do not remove billing integration while a real subscription can still renew.
do $$ begin
 if exists(select 1 from public.pass_subscriptions where stripe_subscription_id is not null and status='active' and current_period_ends_at>now() and not cancel_at_period_end) then
  raise exception 'Encerre a renovação das assinaturas antigas antes da migração.';
 end if;
end; $$;

-- Preserve the already-paid expiry without granting another set of boxes.
insert into public.pass_prepaid(profile_id,ends_at)
select profile_id,current_period_ends_at from public.pass_subscriptions
where status='active' and current_period_ends_at>now()
on conflict(profile_id) do update set ends_at=greatest(public.pass_prepaid.ends_at,excluded.ends_at),updated_at=now();

drop trigger if exists credit_subscription_boxes on public.pass_subscriptions;
drop function if exists public.credit_subscription_boxes();
drop function if exists public.credit_box_purchase(uuid,text,integer,integer);
drop function if exists public.credit_halloween_box_purchase(uuid,text,integer,integer);
drop function if exists public.credit_font_box_purchase(uuid,text,integer,integer);

-- Keep financial history, but remove provider-specific identifiers from live SQL.
do $$ declare entry record; definition text; begin
 for entry in select table_name,column_name from information_schema.columns
  where table_schema='public' and column_name like 'stripe_%'
 loop
  execute format('alter table public.%I rename column %I to %I',entry.table_name,entry.column_name,
   case entry.column_name when 'stripe_session_id' then 'payment_reference' when 'stripe_customer_id' then 'provider_customer_id' else 'provider_subscription_id' end);
 end loop;
 select pg_get_functiondef('public.settle_infinitepay_order(uuid,text,text,integer,text)'::regprocedure) into definition;
 if position('stripe_session_id' in definition)=0 then raise exception 'Confirmação de pagamento divergiu. Revise a migração.'; end if;
 execute replace(definition,'stripe_session_id','payment_reference');
 select pg_get_functiondef('public.credit_pix_boxes()'::regprocedure) into definition;
 execute replace(definition,'stripe_session_id','payment_reference');
 select pg_get_functiondef('public.reserve_infinitepay_order(uuid,uuid,text,text,integer,integer)'::regprocedure) into definition;
 definition:=regexp_replace(definition,'exists\(select 1 from public.pass_subscriptions where profile_id=p_profile_id and status=''active'' and current_period_ends_at>now\(\)\)\s+or\s+','','g');
 if position('pass_subscriptions' in definition)>0 then raise exception 'Reserva de pagamento divergiu. Revise a migração.'; end if;
 execute definition;
end; $$;

create or replace function public.pass_active(p_profile_id uuid)
returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
 select exists(select 1 from public.pass_grants g where g.profile_id=p_profile_id and g.revoked_at is null and g.grant_ends_at>now())
  or exists(select 1 from public.pass_prepaid p where p.profile_id=p_profile_id and p.ends_at>now());
$$;

create or replace function public.get_pass_status()
returns jsonb language sql security definer set search_path=public,auth,pg_temp as $$
 select jsonb_build_object(
  'active',public.pass_active(p.id),
  'freeActive',coalesce(g.revoked_at is null and g.grant_ends_at>now(),false),
  'freeEndsAt',case when g.revoked_at is null and g.grant_ends_at>now() then g.grant_ends_at else null end,
  'prepaidActive',coalesce(x.ends_at>now(),false),
  'prepaidEndsAt',case when x.ends_at>now() then x.ends_at else null end,
  'borderStyle',case when public.box_style_allowed(p.id,'frame',p.pass_border_style) then p.pass_border_style else 'none' end,
  'nameStyle',case when public.box_style_allowed(p.id,'name',p.pass_name_style) then p.pass_name_style else 'none' end
 ) from public.public_profiles p
 left join public.pass_grants g on g.profile_id=p.id
 left join public.pass_prepaid x on x.profile_id=p.id
 where p.id=public.own_profile_id();
$$;

create or replace function public.admin_get_pass_grant(p_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth,pg_temp as $$
begin
 if not public.is_admin() then raise exception 'Somente o proprietário pode acessar o Premium.'; end if;
 if not exists(select 1 from public.public_profiles where id=p_profile_id) then raise exception 'Jogador não encontrado.'; end if;
 return (select jsonb_build_object(
  'freeActive',coalesce(g.revoked_at is null and g.grant_ends_at>now(),false),
  'freeEndsAt',case when g.revoked_at is null and g.grant_ends_at>now() then g.grant_ends_at else null end,
  'paidActive',coalesce(x.ends_at>now(),false),'paidEndsAt',x.ends_at
 ) from public.public_profiles p left join public.pass_grants g on g.profile_id=p.id
 left join public.pass_prepaid x on x.profile_id=p.id where p.id=p_profile_id);
end; $$;

-- The previous table remains only as private financial history.
alter table public.pass_subscriptions rename to retired_billing_history;
revoke all on public.retired_billing_history from public,anon,authenticated,service_role;
notify pgrst,'reload schema';
commit;
