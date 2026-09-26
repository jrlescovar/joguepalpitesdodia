-- Premium concedido pelo admin não adiciona caixas automaticamente.
drop trigger if exists credit_free_pass_boxes on public.pass_grants;
drop function if exists public.credit_free_pass_boxes();

-- Mantém o histórico de concessões antigas, mas impede novos créditos com origem gratuita.
create or replace function public.credit_pass_boxes(p_profile_id uuid, p_source text, p_period_key text)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  if p_profile_id is null or p_source not in ('subscription','pix') or nullif(p_period_key,'') is null then
    raise exception 'Concessão de caixas inválida.';
  end if;
  insert into public.pass_box_rewards(profile_id,source,period_key)
    values(p_profile_id,p_source,p_period_key) on conflict do nothing;
  if found then
    insert into public.box_balances(profile_id,balance) values(p_profile_id,5)
      on conflict(profile_id) do update set balance=public.box_balances.balance+5;
  end if;
end;
$$;
revoke execute on function public.credit_pass_boxes(uuid,text,text) from public,anon,authenticated;
