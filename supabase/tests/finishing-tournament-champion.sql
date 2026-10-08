do $$
declare winner uuid:='2d3d76aa-e9f4-4043-aeaa-9e9abe3f6787'; target uuid:='36b34446-4dcf-4d63-8cf3-5ba8ec8d1113'; before_points integer; after_points integer; metadata jsonb;
begin
 select (snapshot->>'rank_points')::integer into before_points from champion_test_profiles where id=winner;
 select rank_points into after_points from public.public_profiles where id=winner;
 if after_points<>before_points+100 then raise exception 'Rank award differs from 100'; end if;
 if (select count(*) from public.paid_tournament_champions where tournament_id=target and profile_id=winner)<>1 then raise exception 'Missing or duplicated champion award'; end if;
 metadata:=public.get_profile_overview_meta(winner);
 if (metadata->>'finishingTournamentWins')::integer<>1 then raise exception 'Wrong medal count'; end if;
 if public.grant_paid_tournament_champion(target,winner,100) then raise exception 'Repeated award was credited'; end if;
 if after_points<>(select rank_points from public.public_profiles where id=winner) then raise exception 'Repeated award changed points'; end if;
 begin
  perform public.grant_paid_tournament_champion(target,'3334060e-9857-48f3-b7b0-24e1cb3fd657',100);
  raise exception 'Non-winner received award';
 exception when raise_exception then
  if sqlerrm<>'O jogador não terminou em primeiro lugar.' then raise; end if;
 end;
 perform set_config('request.jwt.claims','{"role":"authenticated"}',true);
 begin
  perform public.grant_paid_tournament_champion(target,winner,100);
  raise exception 'Player can grant points';
 exception when raise_exception then
  if sqlerrm<>'Acesso negado.' then raise; end if;
 end;
 if has_function_privilege('authenticated','public.grant_paid_tournament_champion(uuid,uuid,integer)','EXECUTE')
  or has_table_privilege('authenticated','public.paid_tournament_champions','INSERT') then raise exception 'Unsafe award permissions'; end if;
 if exists(select 1 from champion_test_profiles b join public.public_profiles p on p.id=b.id
  where case when p.id=winner then b.snapshot-'rank_points'-'updated_at' is distinct from to_jsonb(p)-'rank_points'-'updated_at'
  else b.snapshot is distinct from to_jsonb(p) end) then raise exception 'Unrelated profile fields changed'; end if;
end;
$$;
select 'PASS: exactly 100 rank points, one medal, safe replay, non-winner denied, public metadata and unrelated stats preserved' as result;
