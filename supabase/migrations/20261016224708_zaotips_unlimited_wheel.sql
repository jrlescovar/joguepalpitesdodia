begin;
-- Unlimited spins only for the account explicitly selected by its owner.
-- Keep draw odds, rewards, replay protection, and every other daily limit.
do $$ declare signature text; definition text;
 rule constant text := 'unlimited:=target=''4325ba8c-8b6b-9635-429c-cef8c63ac2d4''::uuid;';
begin
 if not exists(select 1 from public.public_profiles where id='4325ba8c-8b6b-9635-429c-cef8c63ac2d4' and player_id=1000001 and lower(username)='zaotips') then
  raise exception 'The selected account does not match zaotips.';
 end if;
 foreach signature in array array['public.get_daily_wheel_state()','public.spin_daily_wheel(uuid)'] loop
  definition:=pg_get_functiondef(signature::regprocedure);
  if (length(definition)-length(replace(definition,'unlimited:=false;','')))/length('unlimited:=false;')<>1 then
   raise exception 'Unexpected wheel definition: %',signature;
  end if;
  execute replace(definition,'unlimited:=false;',rule);
 end loop;
end $$;
notify pgrst,'reload schema';
commit;
