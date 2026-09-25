begin;

-- Add or change difficulty points on a published challenge while picks are still open.
-- The selected points apply to every pick on that challenge when it is settled.
create or replace function public.set_open_prediction_rank_points(
  p_day_id date, p_slot smallint, p_rank_points jsonb
)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
declare game public.predictions; updated_options jsonb;
begin
  if not public.is_admin() then raise exception 'Somente o proprietário pode definir pontosRank.'; end if;
  select * into game from public.predictions where day_id=p_day_id and slot=p_slot for update;
  if not found then raise exception 'Aposta não encontrada.'; end if;
  if game.status <> 'open' or game.closes_at <= now() then
    raise exception 'Os pontosRank só podem ser alterados antes do encerramento da aposta.';
  end if;
  if coalesce(jsonb_typeof(p_rank_points),'') <> 'array' then
    raise exception 'Defina os pontos de cada opção.';
  end if;
  if jsonb_array_length(p_rank_points) <> jsonb_array_length(game.options) then
    raise exception 'Defina os pontos de todas as opções.';
  end if;
  if exists (
    select 1 from jsonb_array_elements_text(p_rank_points) value
    where not case when value ~ '^[0-9]{1,4}$' then value::integer between 1 and 1000 else false end
  ) then raise exception 'Use de 1 a 1000 pontos por opção.'; end if;

  select jsonb_agg(o.value || jsonb_build_object('rankPoints',r.value::integer) order by o.ordinality)
  into updated_options
  from jsonb_array_elements(game.options) with ordinality o(value,ordinality)
  join jsonb_array_elements_text(p_rank_points) with ordinality r(value,ordinality) using (ordinality);

  update public.predictions set options=updated_options,updated_at=now()
  where day_id=p_day_id and slot=p_slot;
  return jsonb_build_object('ok',true);
end;
$$;

revoke execute on function public.set_open_prediction_rank_points(date,smallint,jsonb) from public,anon,authenticated;
grant execute on function public.set_open_prediction_rank_points(date,smallint,jsonb) to authenticated;
notify pgrst,'reload schema';

commit;
