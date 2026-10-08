do $$
declare day date; prize record; lower_bound integer; supporter_count integer;
begin
  for day in select generate_series('2026-10-05'::date,'2026-10-11'::date,'1 day')::date loop
    lower_bound:=0; supporter_count:=0;
    for prize in select * from public.daily_wheel_prizes
      where kind<>'supporter' or extract(dow from day)=4 order by position loop
      if public.wheel_prize_position(day,lower_bound)<>prize.position
         or public.wheel_prize_position(day,lower_bound+prize.weight-1)<>prize.position then
        raise exception 'Incorrect weighted interval for % on %',prize.position,day;
      end if;
      if prize.kind='supporter' then supporter_count:=supporter_count+prize.weight; end if;
      lower_bound:=lower_bound+prize.weight;
    end loop;
    if extract(dow from day)=4 then
      if supporter_count*20<>lower_bound then raise exception 'Thursday supporter chance is not 5%%'; end if;
    elsif supporter_count<>0 then raise exception 'Supporter can be drawn outside Thursday';
    end if;
  end loop;
  if has_function_privilege('authenticated','public.wheel_prize_position(date,integer)','EXECUTE')
     or has_function_privilege('anon','public.wheel_prize_position(date,integer)','EXECUTE') then
    raise exception 'Clients can override the drawing date or random number';
  end if;
  if position('public.wheel_prize_position(today)' in pg_get_functiondef('public.spin_daily_wheel(uuid)'::regprocedure))=0
    or position('if prior is not null then return prior' in pg_get_functiondef('public.spin_daily_wheel(uuid)'::regprocedure))=0 then
    raise exception 'Spin integration or idempotency missing';
  end if;
end;
$$;
select 'PASS: supporter 5% Thursday, excluded on six other days, server-only draw and prior rewards preserved' as result;
