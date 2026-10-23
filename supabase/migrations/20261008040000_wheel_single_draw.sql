begin;
do $$
declare definition text; anchor text := ' select * into strict prize from public.daily_wheel_prizes where position=public.wheel_prize_position(today);';
begin
 definition:=pg_get_functiondef('public.spin_daily_wheel(uuid)'::regprocedure);
 if position(anchor in definition)=0 then raise exception 'Definição da roleta inesperada.'; end if;
 execute replace(definition,anchor,' roll:=public.wheel_prize_position(today);'||chr(10)||' select * into strict prize from public.daily_wheel_prizes where position=roll;');
end;
$$;
-- Check every draw resolves one catalog entry without granting rewards.
do $$
declare draw_position integer; prize_count integer; day_offset integer; sample integer;
begin
 for day_offset in 0..6 loop
  for sample in 1..1000 loop
   draw_position:=public.wheel_prize_position('2026-10-05'::date+day_offset);
   select count(*) into prize_count from public.daily_wheel_prizes where position=draw_position;
   if prize_count<>1 then raise exception 'Prêmio inexistente no catálogo.'; end if;
   if day_offset<>3 and exists(select 1 from public.daily_wheel_prizes where position=draw_position and kind='supporter') then raise exception 'Apoiador fora da quinta-feira.'; end if;
  end loop;
 end loop;
end;
$$;
commit;
