begin;
alter table public.pass_box_rewards add column font_quantity integer not null default 0 check(font_quantity in (0,1));
create or replace function public.credit_pass_boxes(p_profile_id uuid, p_source text, p_period_key text)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  if p_profile_id is null or p_source not in ('subscription','pix') or nullif(p_period_key,'') is null then
    raise exception 'Concessão de caixas inválida.';
  end if;
  insert into public.pass_box_rewards(profile_id,source,period_key,quantity,font_quantity)
    values(p_profile_id,p_source,p_period_key,7,1) on conflict do nothing;
  if found then
    insert into public.box_balances(profile_id,balance) values(p_profile_id,7)
      on conflict(profile_id) do update set balance=public.box_balances.balance+7;
    insert into public.font_box_balances(profile_id,balance) values(p_profile_id,1)
      on conflict(profile_id) do update set balance=public.font_box_balances.balance+1;
  end if;
end;
$$;
revoke execute on function public.credit_pass_boxes(uuid,text,text) from public,anon,authenticated;
commit;
