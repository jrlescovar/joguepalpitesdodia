-- Controlled wheel tests. Execute inside BEGIN/ROLLBACK after the migration.
create or replace function public.wheel_prize_position(p_day date,p_roll integer default null) returns integer
language sql volatile security definer set search_path=public,pg_temp as $$select min(position)::integer from public.daily_wheel_prizes where kind='empty'$$;
do $$ declare target uuid; subject uuid; today date:=(now() at time zone 'America/Sao_Paulo')::date;
 state jsonb; first_result jsonb; again jsonb; request uuid:=gen_random_uuid(); denied boolean; original jsonb;
begin
 select p.id,v.auth_user_id into strict target,subject from public.public_profiles p join public.private_profiles v on v.profile_id=p.id where p.player_id=1000001;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',subject,'role','authenticated')::text,true);
 -- An existing test spin must also consume today's daily allowance.
 if exists(select 1 from public.daily_wheel_spins where profile_id=target and day_id=today) then
  state:=public.get_daily_wheel_state();
  if (state->>'unlimited')::boolean or not (state->>'used')::boolean then raise exception 'Existing owner spin did not consume today';end if;
 end if;
 delete from public.daily_wheel_spins where profile_id=target and day_id=today;
 delete from public.daily_wheel_tickets where profile_id=target and day_id=today;
 delete from public.picks where profile_id=target and prediction_day=today;
 update public.predictions set status='open',closes_at=now()+interval '1 hour' where day_id=today;
 if not exists(select 1 from public.predictions where day_id=today) then raise exception 'Missing today fixtures';end if;
 state:=public.get_daily_wheel_state();
 if (state->>'unlimited')::boolean or (state->>'eligible')::boolean or (state->>'used')::boolean then raise exception 'Owner still bypasses pick requirement';end if;
 denied:=false;
 begin perform public.spin_daily_wheel(gen_random_uuid());exception when others then
  if sqlerrm not like 'Faça todos os palpites abertos%' then raise;end if;
  denied:=true;
 end;
 if not denied then raise exception 'Spin allowed before completing picks';end if;
 insert into public.picks(profile_id,prediction_day,slot,option_id)
 select target,day_id,slot,options->0->>'id' from public.predictions where day_id=today;
 state:=public.get_daily_wheel_state();
 if not (state->>'eligible')::boolean or (state->>'unlimited')::boolean then raise exception 'Normal eligibility not released';end if;
 select to_jsonb(p) into original from public.public_profiles p where id=target;
 first_result:=public.spin_daily_wheel(request);
 again:=public.spin_daily_wheel(request);
 if first_result is distinct from again then raise exception 'Request replay changed result';end if;
 if first_result->>'kind'<>'empty' then raise exception 'Controlled reward mismatch';end if;
 if (select count(*) from public.daily_wheel_spins where profile_id=target and day_id=today)<>1
 or exists(select 1 from public.daily_wheel_spins where profile_id=target and day_id=today and owner_test) then raise exception 'Normal daily receipt incorrect';end if;
 denied:=false;
 begin perform public.spin_daily_wheel(gen_random_uuid());exception when others then
  if sqlerrm not like 'Você já usou seu giro de hoje%' then raise;end if;
  denied:=true;
 end;
 if not denied then raise exception 'Second daily spin allowed';end if;
 state:=public.get_daily_wheel_state();
 if not (state->>'used')::boolean or (state->>'unlimited')::boolean then raise exception 'Normal used state incorrect';end if;
 if original is distinct from (select to_jsonb(p) from public.public_profiles p where id=target) then raise exception 'Empty/replay spin changed profile';end if;
end $$;
