begin;
-- Keep the same nine prizes and odds, with duplicate prizes on opposite sides.
update public.daily_wheel_prizes set
 kind=case position when 0 then 'empty' when 1 then 'classic' when 2 then 'halloween' when 3 then 'font' when 4 then 'empty' when 5 then 'classic' when 6 then 'name' when 7 then 'frame' else 'supporter' end,
 label=case position when 0 then 'Sem recompensa' when 1 then '1 caixa de personalização' when 2 then '1 caixa de Halloween' when 3 then '1 caixa de fontes' when 4 then 'Sem recompensa' when 5 then '1 caixa de personalização' when 6 then '1 caixa de cor de nome' when 7 then '1 caixa de moldura' else 'Apoiador por 1 mês' end,
 weight=case when position=8 then 400 else 950 end;
-- Existing results keep their reward and land on its new visual sector.
update public.daily_wheel_spins set result=jsonb_set(result,'{position}',to_jsonb(
 case (result->>'position')::integer when 0 then 1 when 1 then 2 when 2 then 3 when 3 then 6 when 4 then 7 when 5 then 8 when 6 then 0 when 7 then 5 when 8 then 4 end));

-- Only the fixed owner account may have multiple spins per day. Request UUIDs
-- still guarantee exactly-once reward delivery for retries on every account.
alter table public.daily_wheel_spins drop constraint daily_wheel_spins_pkey;
alter table public.daily_wheel_spins add column spin_id bigint generated always as identity primary key;
alter table public.daily_wheel_spins add column owner_test boolean not null default false;
update public.daily_wheel_spins s set owner_test=true from public.public_profiles p where p.id=s.profile_id and p.player_id=1000001;
create unique index daily_wheel_spins_one_normal_per_day on public.daily_wheel_spins(profile_id,day_id) where not owner_test;
create index daily_wheel_spins_latest_idx on public.daily_wheel_spins(profile_id,day_id,spin_id desc);
revoke all on sequence public.daily_wheel_spins_spin_id_seq from public,anon,authenticated;

create or replace function public.get_daily_wheel_state() returns jsonb
language plpgsql volatile security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); today date:=(now() at time zone 'America/Sao_Paulo')::date; eligible boolean; prior jsonb; unlimited boolean;
begin
 if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
 unlimited:=exists(select 1 from public.public_profiles where id=target and player_id=1000001);
 eligible:=unlimited or public.ensure_daily_wheel_ticket(target,today);
 select result into prior from public.daily_wheel_spins where profile_id=target and day_id=today order by spin_id desc limit 1;
 return jsonb_build_object('dayId',today,'serverTime',floor(extract(epoch from now())*1000),
 'resetsAt',((today+1)::timestamp at time zone 'America/Sao_Paulo'),'eligible',eligible,'used',not unlimited and prior is not null,'unlimited',unlimited,'result',prior,
 'hasPicks',exists(select 1 from public.picks where profile_id=target and prediction_day=today),
 'remaining',(select count(*) from public.predictions p where p.day_id=today and p.status='open' and p.closes_at>now() and not exists(select 1 from public.picks k where k.profile_id=target and k.prediction_day=p.day_id and k.slot=p.slot)),
 'prizes',(select jsonb_agg(jsonb_build_object('position',position,'kind',kind,'label',label,'weight',weight,'chance',weight*100.0/(select sum(weight) from public.daily_wheel_prizes)) order by position) from public.daily_wheel_prizes));
end;$$;

-- Change only owner eligibility/daily limits in the audited reward transaction.
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.spin_daily_wheel(uuid)'::regprocedure);
 if position('if not public.ensure_daily_wheel_ticket(target,today)' in definition)=0
 or position('if exists(select 1 from public.daily_wheel_spins where profile_id=target and day_id=today)' in definition)=0 then
  raise exception 'Unexpected daily spin definition';
 end if;
 definition:=replace(definition,'replacement boolean:=false; output jsonb;','replacement boolean:=false; output jsonb; unlimited boolean;');
 definition:=replace(definition,'if not public.ensure_daily_wheel_ticket(target,today)',
  'unlimited:=exists(select 1 from public.public_profiles where id=target and player_id=1000001);'||chr(10)||
  ' if unlimited then insert into public.daily_wheel_tickets(profile_id,day_id) values(target,today) on conflict do nothing; end if;'||chr(10)||
  ' if not unlimited and not public.ensure_daily_wheel_ticket(target,today)');
 definition:=replace(definition,'if exists(select 1 from public.daily_wheel_spins where profile_id=target and day_id=today)',
  'if not unlimited and exists(select 1 from public.daily_wheel_spins where profile_id=target and day_id=today)');
 definition:=replace(definition,'public.credit_pass_boxes(target,''wheel'',today::text)','public.credit_pass_boxes(target,''wheel'',today::text||'':''||p_request_id::text)');
 definition:=replace(definition,'daily_wheel_spins(profile_id,day_id,request_id,result) values(target,today,p_request_id,output)',
  'daily_wheel_spins(profile_id,day_id,request_id,result,owner_test) values(target,today,p_request_id,output,unlimited)');
 execute definition;
end;$$;
revoke all on function public.get_daily_wheel_state(),public.spin_daily_wheel(uuid) from public,anon,authenticated;
grant execute on function public.get_daily_wheel_state(),public.spin_daily_wheel(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
