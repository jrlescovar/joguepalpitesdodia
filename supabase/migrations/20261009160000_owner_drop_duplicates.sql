begin;
create table public.level_drop_xp_repairs(drop_id uuid primary key references public.level_drops(id),previous_reward jsonb not null,xp_awarded integer not null,created_at timestamptz not null default now());
alter table public.level_drop_xp_repairs enable row level security;
revoke all on public.level_drop_xp_repairs from public,anon,authenticated;
do $$ declare definition text; marker text:='owned:=exists(select 1 from public.box_inventory where profile_id=target and kind=choice.kind and style=choice.style);'; begin
 select pg_get_functiondef('public.interact_level_drop(uuid,uuid,boolean)'::regprocedure) into definition;
 if position(marker in definition)=0 then raise exception 'Duplicate code not found'; end if;
 execute replace(definition,marker,'owned:=exists(select 1 from public.public_profiles where id=target and player_id=1000001) or exists(select 1 from public.box_inventory where profile_id=target and kind=choice.kind and style=choice.style);');
end $$;
do $$ declare target uuid:='4325ba8c-8b6b-9635-429c-cef8c63ac2d4'; d record; amount integer; total integer:=0; player record; progress integer[]; corrected jsonb; begin
 select level,xp into player from public.public_profiles where id=target and player_id=1000001 for update;
 if not found then raise exception 'Owner not found'; end if;
 for d in select * from public.level_drops where profile_id=target and reward is not null and reward->>'duplicate'='false' and (reward->>'xpAwarded')::integer=0 for update loop
  amount:=public.pass_xp(case d.reward->>'rarity' when 'common' then 25 when 'rare' then 50 when 'epic' then 100 when 'mythic' then 250 else 500 end,target);
  insert into public.level_drop_xp_repairs(drop_id,previous_reward,xp_awarded) values(d.id,d.reward,amount);
  corrected:=d.reward||jsonb_build_object('duplicate',true,'xpAwarded',amount);
  update public.level_drops set reward=corrected where id=d.id;
  update public.box_openings set duplicate=true,xp_awarded=amount where id=(d.reward->>'id')::uuid and profile_id=target;
  update public.level_drop_requests set response=jsonb_set(response,'{reward}',corrected) where profile_id=target and response->>'id'=d.id::text and response->'reward' is not null and response->'reward'<>'null'::jsonb;
  total:=total+amount;
 end loop;
 if total>0 then
  progress:=public.award_xp(player.level,player.xp,total);
  update public.public_profiles set level=progress[1],xp=progress[2],updated_at=now() where id=target;
 end if;
end $$;
notify pgrst,'reload schema';
commit;
select count(*) corrected_drops,sum(xp_awarded) restored_xp from public.level_drop_xp_repairs;
