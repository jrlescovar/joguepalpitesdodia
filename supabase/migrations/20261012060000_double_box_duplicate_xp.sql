begin;

-- Retain historical rewards and drop rewards. Only new box openings use
-- doubled base XP, followed by the existing 50% supporter bonus.
alter table public.box_openings drop constraint box_openings_xp_awarded_check;
alter table public.box_openings add constraint box_openings_xp_awarded_check
 check(xp_awarded in (0,25,50,100,250,500,38,75,150,375,750,200,300,1000,1500));

do $$
declare fn_name text; definition text;
 old_reward text:='reward := case selected_rarity when ''common'' then 25 when ''rare'' then 50 when ''epic'' then 100 when ''mythic'' then 250 else 500 end;';
 new_reward text:='reward := case selected_rarity when ''common'' then 50 when ''rare'' then 100 when ''epic'' then 200 when ''mythic'' then 500 else 1000 end;';
begin
 foreach fn_name in array array['open_box','open_name_box','open_frame_box','open_halloween_box','open_font_box'] loop
  definition:=pg_get_functiondef(('public.'||fn_name||'(uuid)')::regprocedure);
  if position('reward := public.pass_xp(reward,target);' in definition)=0 then
   raise exception 'Supporter multiplier missing in %',fn_name;
  end if;
  if position(new_reward in definition)=0 then
   if position(old_reward in definition)=0 then raise exception 'Unexpected duplicate reward in %',fn_name; end if;
   execute replace(definition,old_reward,new_reward);
  end if;
 end loop;
end;
$$;

notify pgrst,'reload schema';
commit;
