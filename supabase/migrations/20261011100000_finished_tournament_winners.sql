begin;

-- Final results are public profile data; prediction choices stay restricted to entrants.
create or replace function public.finished_paid_tournament_winners_json(p_tournament_id uuid) returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce(jsonb_agg(public.get_public_profile(e.profile_id)
   || jsonb_build_object('position',1,'correctAnswers',e.correct_answers)
   order by e.registered_at,p.player_id),'[]'::jsonb)
 from public.paid_tournaments t join public.paid_tournament_entries e on e.tournament_id=t.id
 join public.public_profiles p on p.id=e.profile_id
 where t.id=p_tournament_id and now()>=t.ends_at
  and (select count(*) from public.paid_tournament_predictions g where g.tournament_id=t.id and g.status='settled')=t.prediction_count
  and not exists(select 1 from public.paid_tournament_predictions g where g.tournament_id=t.id and g.status<>'settled')
  and e.correct_answers=(select max(correct_answers) from public.paid_tournament_entries where tournament_id=t.id);
$$;
revoke all on function public.finished_paid_tournament_winners_json(uuid) from public,anon,authenticated;

do $$
declare definition text; anchor text:='''participants'',participants,''players'',players,''ownRank'',own_rank,';
begin
 definition:=pg_get_functiondef('public.get_finishing_tournament(uuid)'::regprocedure);
 if position(anchor in definition)=0 then raise exception 'Unexpected tournament serializer.'; end if;
 if position('finished_paid_tournament_winners_json' in definition)>0 then raise exception 'Winner serializer already installed.'; end if;
 execute replace(definition,anchor,anchor||'''winners'',public.finished_paid_tournament_winners_json(tournament.id),');
end $$;
notify pgrst,'reload schema';
commit;
