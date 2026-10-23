begin;
do $$
declare fn record; definition text; marker text; replacement text;
begin
 for fn in select oid,proname from pg_proc where pronamespace='public'::regnamespace and proname in ('open_box','open_font_box','open_halloween_box','open_name_box','open_frame_box','interact_level_drop') loop
  definition:=pg_get_functiondef(fn.oid);
  if fn.proname='interact_level_drop' then
   marker:='progress:=public.award_xp(player.level,player.xp,xp_reward);';
   replacement:='xp_reward:=public.pass_xp(xp_reward,target); '||marker;
  else
   marker:='progress := public.award_xp(player.level,player.xp,reward);';
   replacement:='reward := public.pass_xp(reward,target); '||marker;
  end if;
  if position(replacement in definition)=0 then
   if position(marker in definition)=0 then raise exception 'XP code not found in %',fn.proname; end if;
   execute replace(definition,marker,replacement);
  end if;
 end loop;
end $$;
notify pgrst,'reload schema';
commit;
select 'Premium duplicate XP enabled for all boxes and drops' result;
