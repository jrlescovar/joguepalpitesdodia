begin;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '00000000-0000-0000-0000-000000000001',
  'email', (select owner_email from public.app_config where singleton)
)::text, true);

do $$
declare
  game public.predictions;
  player public.public_profiles;
  chosen_option text;
  before_xp bigint;
  result jsonb;
begin
  select g.* into game
    from public.predictions g
    where g.status = 'open' and g.closes_at > now()
      and exists (select 1 from public.public_profiles p
        where not exists (select 1 from public.picks k
          where k.profile_id = p.id and k.prediction_day = g.day_id and k.slot = g.slot))
    order by g.day_id, g.slot limit 1;
  if not found then raise exception 'É necessário um palpite aberto com prazo futuro.'; end if;
  select p.* into player from public.public_profiles p
    where not exists (select 1 from public.picks k
      where k.profile_id = p.id and k.prediction_day = game.day_id and k.slot = game.slot)
    order by p.player_id desc limit 1;
  chosen_option := game.options->0->>'id';
  before_xp := public.total_xp(player.level, player.xp);
  result := public.admin_add_pick(player.id, game.day_id, game.slot, chosen_option);
  if result->>'status' <> 'pending' then raise exception 'O palpite aberto não ficou pendente.'; end if;
  if not exists (select 1 from public.picks k where k.profile_id = player.id
    and k.prediction_day = game.day_id and k.slot = game.slot
    and k.option_id = chosen_option and k.status = 'pending') then
    raise exception 'O palpite do jogador não foi salvo.';
  end if;
  if (select public.total_xp(level, xp) from public.public_profiles where id = player.id)
    <> before_xp + public.pass_xp(5, player.id) then
    raise exception 'XP inicial incorreto.';
  end if;
end;
$$;
rollback;
