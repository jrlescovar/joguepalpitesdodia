begin;
do $$ declare definition text; marker text:='set tier=tier+1,clicks_left=5'; begin
 select pg_get_functiondef('public.interact_level_drop(uuid,uuid,boolean)'::regprocedure) into definition;
 if position(marker in definition)=0 then raise exception 'Evolution code not found'; end if;
 execute replace(definition,marker,'set tier=tier+1,clicks_left=case when tier=3 then 1 else 5 end');
end $$;
update public.level_drops set clicks_left=1 where tier=4 and status='playing' and clicks_left>1 and received_at is not null;
notify pgrst,'reload schema';
commit;
select 'Legendary opens after one click' result;
