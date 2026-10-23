begin;
-- Keep the existing legendary sector and its 5% Thursday weight.
-- Daily eligibility follows the Brasília calendar supplied by spin_daily_wheel.
create or replace function public.wheel_prize_position(p_day date,p_roll integer default null)
returns integer language plpgsql volatile security definer set search_path=public,pg_temp as $$
declare total integer; roll integer; cursor_weight integer:=0; prize record;
begin
 if p_day is null then raise exception 'Data do giro obrigatória.';end if;
 select sum(weight) into total from public.daily_wheel_prizes
 where kind<>'legendary' or extract(dow from p_day)=4;
 if total is null or total>1000000000 then raise exception 'Roleta temporariamente indisponível.';end if;
 roll:=coalesce(p_roll,public.wheel_random_index(total));
 if roll<0 or roll>=total then raise exception 'Índice do giro inválido.';end if;
 for prize in select position,weight from public.daily_wheel_prizes
 where kind<>'legendary' or extract(dow from p_day)=4 order by position loop
  cursor_weight:=cursor_weight+prize.weight;
  if roll<cursor_weight then return prize.position;end if;
 end loop;
 raise exception 'Roleta temporariamente indisponível.';
end;$$;
notify pgrst,'reload schema';
commit;
