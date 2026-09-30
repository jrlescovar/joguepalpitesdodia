create or replace function public.battle_today()
returns date language sql stable as $$
  select timezone('America/Sao_Paulo', now())::date;
$$;
