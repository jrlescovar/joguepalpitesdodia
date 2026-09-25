begin;

-- Slot 0 is the Aposta do Dia; slots 1–9 are the nine Extras.
alter table public.predictions drop constraint if exists predictions_slot_check;
alter table public.predictions add constraint predictions_slot_check check (slot between 0 and 9);
alter table public.picks drop constraint if exists picks_slot_check;
alter table public.picks add constraint picks_slot_check check (slot between 0 and 9);

create or replace function public.publish_prediction_ranked(
  p_day_id date, p_slot smallint, p_title text, p_description text,
  p_options jsonb, p_rank_points jsonb, p_closes_at timestamptz
)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare previous_main date; normalized jsonb;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode publicar desafios.'; end if;
  if p_day_id<timezone('America/Sao_Paulo',now())::date then raise exception 'Escolha hoje ou uma data futura.'; end if;
  if p_slot not between 0 and 9 then raise exception 'Escolha a Aposta do Dia ou uma das nove Extras.'; end if;
  if exists(select 1 from public.predictions where day_id=p_day_id and slot=p_slot) then raise exception 'Essa aposta já foi publicada nesta data.'; end if;
  if p_slot>0 and not exists(select 1 from public.predictions where day_id=p_day_id and slot=p_slot-1) then raise exception 'Publique primeiro a Aposta do Dia e as Extras em ordem.'; end if;
  if char_length(trim(p_title)) not between 5 and 120 or char_length(coalesce(p_description,''))>800 then raise exception 'Confira o título e a descrição.'; end if;
  if coalesce(jsonb_typeof(p_options),'')<>'array' then raise exception 'Informe de 2 a 4 opções diferentes.'; end if;
  if jsonb_array_length(p_options) not between 2 and 4 then raise exception 'Informe de 2 a 4 opções diferentes.'; end if;
  if coalesce(jsonb_typeof(p_rank_points),'')<>'array' then raise exception 'Defina os pontos de cada opção.'; end if;
  if jsonb_array_length(p_rank_points)<>jsonb_array_length(p_options) then raise exception 'Defina os pontos de cada opção.'; end if;
  if exists(select 1 from jsonb_array_elements_text(p_rank_points) value where not case when value ~ '^[0-9]{1,4}$' then value::integer between 1 and 1000 else false end) then raise exception 'Use de 1 a 1000 pontos por opção.'; end if;
  if exists(select 1 from jsonb_array_elements_text(p_options) value where trim(value)='' or char_length(value)>100) then raise exception 'Confira as opções.'; end if;
  if (select count(distinct lower(trim(value))) from jsonb_array_elements_text(p_options) value)<>jsonb_array_length(p_options) then raise exception 'As opções precisam ser diferentes.'; end if;
  select jsonb_agg(jsonb_build_object('id',o.ordinality::text,'label',trim(o.value),'rankPoints',r.value::integer) order by o.ordinality) into normalized
  from jsonb_array_elements_text(p_options) with ordinality o(value,ordinality)
  join jsonb_array_elements_text(p_rank_points) with ordinality r(value,ordinality) using (ordinality);
  if p_closes_at<=now() or timezone('America/Sao_Paulo',p_closes_at)::date<>p_day_id then raise exception 'O prazo deve ser futuro e dentro do dia do desafio em Brasília.'; end if;
  select max(day_id) into previous_main from public.predictions where slot=0 and day_id<p_day_id;
  insert into public.predictions(day_id,slot,title,description,options,closes_at,previous_day_id) values(p_day_id,p_slot,trim(p_title),coalesce(trim(p_description),''),normalized,p_closes_at,previous_main);
  return jsonb_build_object('ok',true);
end;
$$;

revoke execute on function public.publish_prediction_ranked(date,smallint,text,text,jsonb,jsonb,timestamptz) from public,anon,authenticated;
grant execute on function public.publish_prediction_ranked(date,smallint,text,text,jsonb,jsonb,timestamptz) to authenticated;
create or replace function public.get_admin_state()
returns jsonb language plpgsql stable security definer set search_path = public, auth, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode acessar a administração.'; end if;
  return jsonb_build_object(
    'registrationsOpen',(select registrations_open from public.app_config where singleton),
    'predictions',coalesce((select jsonb_agg(item order by (item->>'dayId')::date desc,(item->>'slot')::integer asc) from (select public.prediction_json(p) item from public.predictions p order by day_id desc,slot asc limit 310) recent),'[]'::jsonb)
  );
end;
$$;

notify pgrst, 'reload schema';
commit;
