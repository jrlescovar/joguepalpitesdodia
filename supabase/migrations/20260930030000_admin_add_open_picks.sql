begin;

do $$
declare definition text;
begin
  definition := pg_get_functiondef('public.admin_add_pick(uuid,date,smallint,text)'::regprocedure);
  if position('if game.closes_at > now() or game.status = ''settling'' then' in definition) = 0 then
    raise exception 'A condição esperada em admin_add_pick não foi encontrada.';
  end if;
  definition := replace(definition,
    'if game.closes_at > now() or game.status = ''settling'' then',
    'if game.status = ''settling'' then');
  definition := replace(definition,
    'Aguarde a aposta fechar e o resultado terminar de ser processado.',
    'Aguarde o resultado terminar de ser processado.');
  execute definition;
end;
$$;

notify pgrst, 'reload schema';
commit;
