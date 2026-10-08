begin;

-- The visual catalog keeps its 5% supporter sector every day. Only Thursday
-- draws (Brasilia calendar, supplied by spin_daily_wheel) can select it.
create function public.wheel_prize_position(p_day date,p_roll integer default null)
returns integer language plpgsql volatile security definer set search_path=public,pg_temp as $$
declare total integer; roll integer; cursor_weight integer:=0; prize record;
begin
  if p_day is null then raise exception 'Data do giro obrigatória.'; end if;
  select sum(weight) into total from public.daily_wheel_prizes
    where kind<>'supporter' or extract(dow from p_day)=4;
  if total is null or total>1000000000 then raise exception 'Roleta temporariamente indisponível.'; end if;
  roll:=coalesce(p_roll,public.wheel_random_index(total));
  if roll<0 or roll>=total then raise exception 'Índice do giro inválido.'; end if;
  for prize in select position,weight from public.daily_wheel_prizes
    where kind<>'supporter' or extract(dow from p_day)=4 order by position
  loop
    cursor_weight:=cursor_weight+prize.weight;
    if roll<cursor_weight then return prize.position; end if;
  end loop;
  raise exception 'Roleta temporariamente indisponível.';
end;
$$;
revoke all on function public.wheel_prize_position(date,integer) from public,anon,authenticated;

do $$
declare definition text; anchor text;
begin
  if (select sum(weight) from public.daily_wheel_prizes where kind='supporter')*20
     <> (select sum(weight) from public.daily_wheel_prizes) then
    raise exception 'Apoiador deve manter exatamente 5%% de chance nas quintas.';
  end if;
  definition:=pg_get_functiondef('public.spin_daily_wheel(uuid)'::regprocedure);
  anchor:=' select sum(weight) into total from public.daily_wheel_prizes;'||chr(10)||
    ' if total is null or total>1000000000 then raise exception ''Roleta temporariamente indisponível.''; end if;'||chr(10)||
    ' roll:=public.wheel_random_index(total);'||chr(10)||
    ' for prize in select * from public.daily_wheel_prizes order by position loop'||chr(10)||
    '  cursor_weight:=cursor_weight+prize.weight;'||chr(10)||
    '  exit when roll<cursor_weight;'||chr(10)||' end loop;';
  if position(anchor in definition)=0 then raise exception 'Definição de sorteio inesperada.'; end if;
  execute replace(definition,anchor,
    ' select * into strict prize from public.daily_wheel_prizes where position=public.wheel_prize_position(today);');
end;
$$;
notify pgrst,'reload schema';
commit;
