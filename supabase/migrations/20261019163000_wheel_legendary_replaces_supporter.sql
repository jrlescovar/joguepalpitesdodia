begin;
select pg_advisory_xact_lock(hashtext('wheel-legendary-prize'));
do $$begin
 if (select count(*) from public.daily_wheel_prizes where kind='supporter' and weight=1200 and position=8)<>1
 or (select sum(weight) from public.daily_wheel_prizes)<>24000 then raise exception 'Unexpected wheel catalog';end if;
end $$;
alter table public.daily_wheel_prizes drop constraint daily_wheel_prizes_kind_check;
alter table public.daily_wheel_prizes add constraint daily_wheel_prizes_kind_check check(kind in ('classic','halloween','font','name','frame','legendary','empty')) not valid;
update public.daily_wheel_prizes set kind='legendary',label='1 Caixa Lendária' where kind='supporter';
alter table public.daily_wheel_prizes validate constraint daily_wheel_prizes_kind_check;
-- The legendary sector is eligible every day, with its unchanged 1200/24000 weight.
do $$
declare definition text; anchor text; ending text; replacement text;
begin
 definition:=pg_get_functiondef('public.wheel_prize_position(date,integer)'::regprocedure);
 anchor:='where kind<>''supporter'' or extract(dow from p_day)=4';
 if (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>2 then raise exception 'Unexpected day restriction';end if;
 execute replace(definition,anchor,'');
 definition:=pg_get_functiondef('public.spin_daily_wheel(uuid)'::regprocedure);
 anchor:=substring(definition from position(' if prize.kind=''supporter'' then' in definition) for position(' elsif prize.kind<>''empty'' then' in definition)-position(' if prize.kind=''supporter'' then' in definition));
 if anchor is null or anchor='' or position('credit_pass_boxes' in anchor)=0 then raise exception 'Unexpected reward credit branch';end if;
 replacement:=' if prize.kind=''legendary'' then'||chr(10)||
 '  insert into public.level_drops(profile_id,milestone,received_at,drop_kind,tier,clicks_left,status)'||chr(10)||
 '  values(target,0,now(),''legendary'',4,0,''ready'');'||chr(10)||
 '  boxes:=jsonb_build_object(''legendary'',1);'||chr(10);
 definition:=replace(definition,anchor,replacement);
 definition:=replace(definition,'-- A newly earned pass has already credited its benefits exactly once above.','-- Legendary boxes were credited directly; regular boxes use their existing balances.');
 ending:='if prize.kind<>''supporter'' or replacement then';
 if position(ending in definition)=0 then raise exception 'Unexpected regular box credit condition';end if;
 definition:=replace(definition,ending,'if prize.kind<>''legendary'' then');
 if position('credit_pass_boxes' in definition)>0 or position('pass_prepaid' in definition)>0 then raise exception 'Supporter credit still present';end if;
 execute definition;
end $$;
notify pgrst,'reload schema';
commit;
