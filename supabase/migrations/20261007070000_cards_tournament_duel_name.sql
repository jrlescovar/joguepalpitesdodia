begin;
update public.paid_tournaments set name='Torneio Duelo de Cartões'
where id='671f995b-18bf-4c49-a706-caff6e580e19' and metric='cards';
do $$
begin
  if not exists(select 1 from public.paid_tournaments
    where id='671f995b-18bf-4c49-a706-caff6e580e19' and name='Torneio Duelo de Cartões') then
    raise exception 'Torneio de cartões não encontrado.';
  end if;
end;
$$;
notify pgrst,'reload schema';
commit;
