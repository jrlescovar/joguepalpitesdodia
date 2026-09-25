-- Permite ao proprietário editar PontosRank junto com os demais dados do jogador.
-- A chamada inteira é uma transação: nenhuma alteração parcial é salva em caso de erro.
create or replace function public.admin_update_profile_ranked(
  p_profile_id uuid,
  p_username text,
  p_avatar_color text,
  p_level integer,
  p_xp integer,
  p_green integer,
  p_red integer,
  p_green_streak_current integer,
  p_green_streak_max integer,
  p_rank_points integer
)
returns jsonb language plpgsql security definer set search_path = public, auth, pg_temp as $$
begin
  if not public.is_admin() then
    raise exception 'Somente o proprietário pode editar jogadores.';
  end if;
  if p_rank_points is null or p_rank_points < 0 or p_rank_points > 1000000 then
    raise exception 'Use de 0 a 1000000 pontosRank.';
  end if;

  perform public.admin_update_profile(
    p_profile_id, p_username, p_avatar_color, p_level, p_xp, p_green, p_red,
    p_green_streak_current, p_green_streak_max
  );
  update public.public_profiles
     set rank_points = p_rank_points, updated_at = now()
   where id = p_profile_id;
  return jsonb_build_object('ok', true);
end;
$$;

revoke execute on function public.admin_update_profile_ranked(uuid,text,text,integer,integer,integer,integer,integer,integer,integer) from public, anon, authenticated;
grant execute on function public.admin_update_profile_ranked(uuid,text,text,integer,integer,integer,integer,integer,integer,integer) to authenticated;
notify pgrst, 'reload schema';
