begin;

-- Restore the existing normal daily eligibility and limit for the former test account.
-- Keep prize odds, request replay protection and historical rewards unchanged.
do $$ declare signature text; definition text;
 old_rule constant text:='unlimited:=exists(select 1 from public.public_profiles where id=target and player_id=1000001);';
begin
 foreach signature in array array['public.get_daily_wheel_state()','public.spin_daily_wheel(uuid)'] loop
  definition:=pg_get_functiondef(signature::regprocedure);
  if position(old_rule in definition)=0 then raise exception 'Unexpected wheel definition: %',signature;end if;
  execute replace(definition,old_rule,'unlimited:=false;');
 end loop;
end $$;

notify pgrst,'reload schema';
commit;
