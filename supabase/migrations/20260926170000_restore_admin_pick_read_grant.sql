-- O painel administrativo usa esta RPC com a sessão autenticada do proprietário.
-- A função mantém a checagem public.is_admin() antes de retornar os palpites.
grant execute on function public.get_admin_picks_for_day(uuid,date) to authenticated;
