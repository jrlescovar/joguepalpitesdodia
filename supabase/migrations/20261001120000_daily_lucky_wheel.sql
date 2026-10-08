begin;

-- Reward-only boxes. No purchase tables, prices or checkout endpoints.
create table public.name_box_balances (
 profile_id uuid primary key references public.public_profiles(id) on delete cascade,
 balance integer not null default 0 check(balance>=0)
);
create table public.frame_box_balances (
 profile_id uuid primary key references public.public_profiles(id) on delete cascade,
 balance integer not null default 0 check(balance>=0)
);
alter table public.name_box_balances enable row level security;
alter table public.frame_box_balances enable row level security;
revoke all on public.name_box_balances,public.frame_box_balances from public,anon,authenticated;

-- Serialize openings for the same player before locking balances. This also
-- prevents inventory races between different box types and keeps the same
-- profile -> balance lock order as pass payments and wheel rewards.
do $$
declare definition text; function_name text; kind text;
begin
 foreach function_name in array array['open_box','open_font_box','open_halloween_box'] loop
  definition:=pg_get_functiondef(format('public.%I(uuid)',function_name)::regprocedure);
  if position('insert into public.' in definition)=0 then raise exception 'Unexpected box opening definition'; end if;
  -- Only insert the profile lock before the first balance INSERT, not inventory/history.
  definition:=replace(definition,format('insert into public.%s(profile_id,balance)',case function_name when 'open_box' then 'box_balances' when 'open_font_box' then 'font_box_balances' else 'halloween_box_balances' end),
   'perform 1 from public.public_profiles where id=target for update;'||chr(10)||format('  insert into public.%s(profile_id,balance)',case function_name when 'open_box' then 'box_balances' when 'open_font_box' then 'font_box_balances' else 'halloween_box_balances' end));
  execute definition;
 end loop;
 foreach kind in array array['name','frame'] loop
  definition:=pg_get_functiondef('public.open_box(uuid)'::regprocedure);
  if position('c.theme=''classic''' in definition)=0 then raise exception 'Unexpected classic pool'; end if;
  definition:=replace(definition,'public.open_box(',format('public.open_%s_box(',kind));
  definition:=replace(definition,'public.box_balances',format('public.%s_box_balances',kind));
  definition:=replace(definition,'c.theme=''classic''',format('c.theme=''classic'' and k.kind=%L',kind));
  execute definition;
 end loop;
end;$$;
revoke all on function public.open_name_box(uuid),public.open_frame_box(uuid) from public,anon,authenticated;
grant execute on function public.open_name_box(uuid),public.open_frame_box(uuid) to authenticated;

create function public.get_name_box_state() returns jsonb
language sql stable security definer set search_path=public,auth,pg_temp as $$
 select jsonb_build_object('balance',coalesce((select balance from public.name_box_balances where profile_id=public.own_profile_id()),0),
 'inventory',coalesce((select jsonb_agg(jsonb_build_object('kind',i.kind,'style',i.style,'rarity',c.rarity) order by i.acquired_at)
 from public.box_inventory i join public.box_style_catalog c on c.style=i.style
 where i.profile_id=public.own_profile_id() and i.kind='name' and c.theme='classic'),'[]'::jsonb));
$$;
create function public.get_frame_box_state() returns jsonb
language sql stable security definer set search_path=public,auth,pg_temp as $$
 select jsonb_build_object('balance',coalesce((select balance from public.frame_box_balances where profile_id=public.own_profile_id()),0),
 'inventory',coalesce((select jsonb_agg(jsonb_build_object('kind',i.kind,'style',i.style,'rarity',c.rarity) order by i.acquired_at)
 from public.box_inventory i join public.box_style_catalog c on c.style=i.style
 where i.profile_id=public.own_profile_id() and i.kind='frame' and c.theme='classic'),'[]'::jsonb));
$$;
revoke all on function public.get_name_box_state(),public.get_frame_box_state() from public,anon,authenticated;
grant execute on function public.get_name_box_state(),public.get_frame_box_state() to authenticated;

create table public.daily_wheel_prizes (
 position smallint primary key check(position between 0 and 8),
 kind text not null check(kind in ('classic','halloween','font','name','frame','supporter','empty')),
 label text not null,
 weight integer not null check(weight>0)
);
-- 5% supporter. Other eight slots share 95% equally, pending final tuning.
insert into public.daily_wheel_prizes values
 (0,'classic','1 caixa de personalização',950),(1,'halloween','1 caixa de Halloween',950),
 (2,'font','1 caixa de fontes',950),(3,'name','1 caixa de cor de nome',950),
 (4,'frame','1 caixa de moldura',950),(5,'supporter','Apoiador por 1 mês',400),
 (6,'empty','Sem recompensa',950),(7,'classic','1 caixa de personalização',950),
 (8,'empty','Sem recompensa',950);
create table public.daily_wheel_tickets (
 profile_id uuid not null references public.public_profiles(id) on delete cascade,
 day_id date not null,
 earned_at timestamptz not null default now(),
 primary key(profile_id,day_id)
);
create table public.daily_wheel_spins (
 profile_id uuid not null references public.public_profiles(id) on delete cascade,
 day_id date not null,
 request_id uuid not null,
 result jsonb not null,
 spun_at timestamptz not null default now(),
 primary key(profile_id,day_id),
 unique(profile_id,request_id),
 foreign key(profile_id,day_id) references public.daily_wheel_tickets(profile_id,day_id)
);
alter table public.daily_wheel_prizes enable row level security;
alter table public.daily_wheel_tickets enable row level security;
alter table public.daily_wheel_spins enable row level security;
revoke all on public.daily_wheel_prizes,public.daily_wheel_tickets,public.daily_wheel_spins from public,anon,authenticated;

-- 32 random bits with rejection sampling: no modulo bias, client seed or prize input.
create function public.wheel_random_index(p_count integer) returns integer
language plpgsql volatile set search_path=public,pg_temp as $$
declare sample bigint; draw_limit bigint; bytes bytea;
begin
 if p_count is null or p_count<1 or p_count>1000000000 then raise exception 'Invalid wheel draw size'; end if;
 draw_limit:=(4294967296::bigint/p_count)*p_count;
 loop
  bytes:=decode(substr(replace(gen_random_uuid()::text,'-',''),1,8),'hex');
  sample:=get_byte(bytes,0)::bigint*16777216+get_byte(bytes,1)::bigint*65536+get_byte(bytes,2)::bigint*256+get_byte(bytes,3);
  if sample<draw_limit then return (sample%p_count)::integer; end if;
 end loop;
end;$$;
revoke all on function public.wheel_random_index(integer) from public,anon,authenticated;

create function public.ensure_daily_wheel_ticket(p_profile_id uuid,p_day date) returns boolean
language plpgsql volatile security definer set search_path=public,auth,pg_temp as $$
begin
 if p_profile_id is null or p_day is distinct from (now() at time zone 'America/Sao_Paulo')::date then return false; end if;
 if exists(select 1 from public.daily_wheel_tickets where profile_id=p_profile_id and day_id=p_day) then return true; end if;
 -- At least one actual pick today, and every currently open prediction answered.
 if exists(select 1 from public.picks where profile_id=p_profile_id and prediction_day=p_day)
 and not exists(select 1 from public.predictions p where p.day_id=p_day and p.status='open' and p.closes_at>now()
  and not exists(select 1 from public.picks k where k.profile_id=p_profile_id and k.prediction_day=p.day_id and k.slot=p.slot)) then
  insert into public.daily_wheel_tickets(profile_id,day_id) values(p_profile_id,p_day) on conflict do nothing;
  return true;
 end if;
 return false;
end;$$;
revoke all on function public.ensure_daily_wheel_ticket(uuid,date) from public,anon,authenticated;

alter table public.pass_box_rewards drop constraint pass_box_rewards_source_check;
alter table public.pass_box_rewards add constraint pass_box_rewards_source_check check(source in ('subscription','pix','free','wheel'));
-- A wheel month is an earned supporter period, explicitly including the medal.
create or replace function public.credit_pass_boxes(p_profile_id uuid,p_source text,p_period_key text)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
 if p_profile_id is null or p_source not in ('subscription','pix','wheel') or nullif(p_period_key,'') is null then raise exception 'Concessão de caixas inválida.'; end if;
 insert into public.pass_box_rewards(profile_id,source,period_key,quantity,font_quantity) values(p_profile_id,p_source,p_period_key,7,1) on conflict do nothing;
 if found then
  insert into public.box_balances(profile_id,balance) values(p_profile_id,7) on conflict(profile_id) do update set balance=public.box_balances.balance+7;
  insert into public.font_box_balances(profile_id,balance) values(p_profile_id,1) on conflict(profile_id) do update set balance=public.font_box_balances.balance+1;
 end if;
end;$$;
revoke all on function public.credit_pass_boxes(uuid,text,text) from public,anon,authenticated;
create or replace function public.get_profile_overview_meta(p_profile_id uuid)
returns jsonb language sql volatile security definer set search_path=public,auth,pg_temp as $$
 select jsonb_build_object(
 'globalPosition',1+(select count(*) from public.public_profiles ahead where ahead.rank_points>p.rank_points or (ahead.rank_points=p.rank_points and ahead.player_id<p.player_id)),
 'battleStats',jsonb_build_object('wins',p.battle_wins,'losses',p.battle_losses,'draws',p.battle_draws),'arenaWins',p.arena_wins,
 'supporterMonths',(select count(*) from public.pass_box_rewards r where r.profile_id=p.id and r.source in ('subscription','pix','wheel'))+(select coalesce(sum(m.months),0) from public.supporter_manual_paid_periods m where m.profile_id=p.id)
 ) from public.public_profiles p where p.id=p_profile_id;
$$;
revoke all on function public.get_profile_overview_meta(uuid) from public,anon,authenticated;
grant execute on function public.get_profile_overview_meta(uuid) to authenticated;

create function public.get_daily_wheel_state() returns jsonb
language plpgsql volatile security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); today date:=(now() at time zone 'America/Sao_Paulo')::date; eligible boolean; prior jsonb;
begin
 if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
 eligible:=public.ensure_daily_wheel_ticket(target,today);
 select result into prior from public.daily_wheel_spins where profile_id=target and day_id=today;
 return jsonb_build_object('dayId',today,'serverTime',floor(extract(epoch from now())*1000),
 'resetsAt',((today+1)::timestamp at time zone 'America/Sao_Paulo'),'eligible',eligible,'used',prior is not null,'result',prior,
 'hasPicks',exists(select 1 from public.picks where profile_id=target and prediction_day=today),
 'remaining',(select count(*) from public.predictions p where p.day_id=today and p.status='open' and p.closes_at>now() and not exists(select 1 from public.picks k where k.profile_id=target and k.prediction_day=p.day_id and k.slot=p.slot)),
 'prizes',(select jsonb_agg(jsonb_build_object('position',position,'kind',kind,'label',label,'weight',weight,'chance',weight*100.0/(select sum(weight) from public.daily_wheel_prizes)) order by position) from public.daily_wheel_prizes));
end;$$;

create function public.spin_daily_wheel(p_request_id uuid) returns jsonb
language plpgsql volatile security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); today date:=(now() at time zone 'America/Sao_Paulo')::date;
 prior jsonb; prize record; roll integer; total integer; cursor_weight integer:=0;
 boxes jsonb:='{}'::jsonb; box_type text; box_types text[]:=array['classic','halloween','font','name','frame'];
 box_table text; quantity integer; i integer; ends_at timestamptz; replacement boolean:=false; output jsonb;
begin
 if target is null then raise exception 'Crie seu perfil primeiro.'; end if;
 if p_request_id is null then raise exception 'Identificador do giro obrigatório.'; end if;
 -- All rewards/openings lock the player before balances; one serial transaction.
 perform 1 from public.public_profiles where id=target for update;
 select result into prior from public.daily_wheel_spins where profile_id=target and request_id=p_request_id;
 if prior is not null then return prior; end if;
 if not public.ensure_daily_wheel_ticket(target,today) then raise exception 'Faça todos os palpites abertos para liberar seu giro grátis.'; end if;
 if exists(select 1 from public.daily_wheel_spins where profile_id=target and day_id=today) then raise exception 'Você já usou seu giro de hoje. Volte após 00:00.'; end if;
 select sum(weight) into total from public.daily_wheel_prizes;
 if total is null or total>1000000000 then raise exception 'Roleta temporariamente indisponível.'; end if;
 roll:=public.wheel_random_index(total);
 for prize in select * from public.daily_wheel_prizes order by position loop
  cursor_weight:=cursor_weight+prize.weight;
  exit when roll<cursor_weight;
 end loop;
 if prize.kind='supporter' then
  if public.pass_active(target) then
   replacement:=true;
   for i in 1..7 loop
    box_type:=box_types[public.wheel_random_index(5)+1];
    boxes:=jsonb_set(boxes,array[box_type],to_jsonb(coalesce((boxes->>box_type)::integer,0)+1));
   end loop;
  else
   ends_at:=now()+interval '1 month';
   insert into public.pass_prepaid(profile_id,ends_at,updated_at) values(target,ends_at,now())
    on conflict(profile_id) do update set ends_at=excluded.ends_at,updated_at=now();
   perform public.credit_pass_boxes(target,'wheel',today::text);
   boxes:=jsonb_build_object('classic',7,'font',1);
  end if;
 elsif prize.kind<>'empty' then boxes:=jsonb_build_object(prize.kind,1);
 end if;
 -- A newly earned pass has already credited its benefits exactly once above.
 if prize.kind<>'supporter' or replacement then
  foreach box_type in array box_types loop
   quantity:=coalesce((boxes->>box_type)::integer,0);
   if quantity>0 then
    box_table:=case box_type when 'classic' then 'box_balances' else box_type||'_box_balances' end;
    execute format('insert into public.%I(profile_id,balance) values($1,$2) on conflict(profile_id) do update set balance=public.%I.balance+excluded.balance',box_table,box_table) using target,quantity;
   end if;
  end loop;
 end if;
 output:=jsonb_build_object('dayId',today,'position',prize.position,'kind',prize.kind,'label',case when replacement then '7 caixas aleatórias' else prize.label end,'boxes',boxes,'replacement',replacement,'supporterEndsAt',ends_at);
 insert into public.daily_wheel_spins(profile_id,day_id,request_id,result) values(target,today,p_request_id,output);
 return output;
end;$$;
revoke all on function public.get_daily_wheel_state(),public.spin_daily_wheel(uuid) from public,anon,authenticated;
grant execute on function public.get_daily_wheel_state(),public.spin_daily_wheel(uuid) to authenticated;

-- Existing picks qualify immediately on release; no resubmission or retroactive spins.
do $$
declare target uuid; today date:=(now() at time zone 'America/Sao_Paulo')::date;
begin
 for target in select distinct profile_id from public.picks where prediction_day=today loop
  perform public.ensure_daily_wheel_ticket(target,today);
 end loop;
 select id into target from public.public_profiles where player_id=1000001 and lower(username)='jrlescovar';
 if target is null then raise exception 'Owner test account not found'; end if;
 insert into public.name_box_balances(profile_id,balance) values(target,25);
 insert into public.frame_box_balances(profile_id,balance) values(target,25);
end;$$;
notify pgrst,'reload schema';
commit;
