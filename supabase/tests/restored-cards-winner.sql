begin;
create temporary table kept_tournaments as select jsonb_build_object('tournaments',(select jsonb_agg(to_jsonb(t)-'display_order' order by id) from public.paid_tournaments t where id<>'671f995b-18bf-4c49-a706-caff6e580e19'), 'predictions',(select jsonb_agg(to_jsonb(g) order by tournament_id,slot) from public.paid_tournament_predictions g where tournament_id<>'671f995b-18bf-4c49-a706-caff6e580e19'), 'entries',(select jsonb_agg(to_jsonb(e) order by tournament_id,profile_id) from public.paid_tournament_entries e where tournament_id<>'671f995b-18bf-4c49-a706-caff6e580e19'), 'picks',(select jsonb_agg(to_jsonb(p) order by tournament_id,slot,profile_id) from public.paid_tournament_picks p where tournament_id<>'671f995b-18bf-4c49-a706-caff6e580e19'), 'orders',(select jsonb_agg(to_jsonb(o) order by id) from public.infinitepay_orders o where tournament_id is distinct from '671f995b-18bf-4c49-a706-caff6e580e19'::uuid), 'profiles',(select jsonb_agg(to_jsonb(p) order by id) from public.public_profiles p)) as snapshot;
do $$
declare target uuid:='671f995b-18bf-4c49-a706-caff6e580e19'; subject uuid; outsider uuid; result jsonb; choices jsonb; after_snapshot jsonb; saved_end timestamptz;
begin
 if (select count(*) from public.paid_tournament_predictions where tournament_id=target and status='settled')<>20
  or (select count(*) from public.paid_tournament_entries where tournament_id=target)<>11
  or (select count(*) from public.paid_tournament_picks where tournament_id=target)<>220
  or (select count(*) from public.infinitepay_orders where tournament_id=target)<>5
  or (select count(*) from public.admin_tournament_pick_corrections where tournament_id=target)<>4
 then raise exception 'Incomplete restoration'; end if;
 if exists(select 1 from public.paid_tournament_entries e where e.tournament_id=target and e.correct_answers<>(select count(*) from public.paid_tournament_picks p join public.paid_tournament_predictions g using(tournament_id,slot) where p.tournament_id=target and p.profile_id=e.profile_id and p.option_id=g.winning_option_id)) then raise exception 'Score mismatch'; end if;
 if exists(select 1 from public.tournament_bot_pick_log where tournament_id=target) then raise exception 'Obsolete logs restored'; end if;
 choices:=public.available_paid_tournaments_json();
 if jsonb_array_length(choices)<>3 or choices->0->>'id'<>'2e0617ac-f47a-4abd-aae8-68b4c59aa12d' or choices->1->>'id'<>'2270fca1-406c-4da0-8582-20c20520a44c' or choices->2->>'id'<>target::text then raise exception 'Wrong tournament order'; end if;
 select auth_user_id into subject from public.private_profiles where profile_id='4325ba8c-8b6b-9635-429c-cef8c63ac2d4';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',subject,'role','authenticated')::text,true);
 result:=public.get_finishing_tournament(target);
 if result->>'registrationOpen'<>'false' or result->>'enrolled'<>'true' or (result->>'endsAt')::timestamptz>now() or jsonb_array_length(result->'predictions')<>20 then raise exception 'Restored tournament not closed'; end if;
 if jsonb_array_length(result->'winners')<>1 or result->'winners'->0->>'username'<>'NicoTheGoat' or result->'winners'->0->>'correctAnswers'<>'11' or nullif(result->'winners'->0->>'avatarUrl','') is null then raise exception 'Wrong winner'; end if;
 if public.get_finishing_tournament(null)->>'id'<>'2e0617ac-f47a-4abd-aae8-68b4c59aa12d' or jsonb_array_length(public.get_finishing_tournament('2270fca1-406c-4da0-8582-20c20520a44c')->'winners')<>0 then raise exception 'Upcoming tournament changed'; end if;
 select auth_user_id into outsider from public.private_profiles p where auth_user_id is not null and not exists(select 1 from public.paid_tournament_entries e where e.tournament_id=target and e.profile_id=p.profile_id) limit 1;
 if outsider is null then raise exception 'No outsider fixture'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',outsider,'role','authenticated')::text,true);
 result:=public.get_finishing_tournament(target);
 if result->>'enrolled'<>'false' or jsonb_array_length(result->'predictions')<>0 or jsonb_array_length(result->'players')<>0 or result->'winners'->0->>'correctAnswers'<>'11' then raise exception 'Outsider final result or pick privacy broken'; end if;
 update public.paid_tournament_entries set correct_answers=11 where tournament_id=target and profile_id='403cb4e7-9628-4bf2-800a-74d457680600';
 if jsonb_array_length(public.finished_paid_tournament_winners_json(target))<>2 then raise exception 'Tie omitted'; end if;
 update public.paid_tournament_entries set correct_answers=10 where tournament_id=target and profile_id='403cb4e7-9628-4bf2-800a-74d457680600';
 update public.paid_tournaments set prediction_count=21 where id=target;
 if jsonb_array_length(public.finished_paid_tournament_winners_json(target))<>0 then raise exception 'Incomplete results declared winner'; end if;
 update public.paid_tournaments set prediction_count=20 where id=target;
 select ends_at into saved_end from public.paid_tournaments where id=target;
 update public.paid_tournaments set ends_at=now()+interval '1 hour' where id=target;
 if jsonb_array_length(public.finished_paid_tournament_winners_json(target))<>0 then raise exception 'Early winner'; end if;
 update public.paid_tournaments set ends_at=saved_end where id=target;
 if has_function_privilege('authenticated','public.finished_paid_tournament_winners_json(uuid)','EXECUTE') or has_function_privilege('anon','public.finished_paid_tournament_winners_json(uuid)','EXECUTE') then raise exception 'Private helper exposed'; end if;
 select jsonb_build_object('tournaments',(select jsonb_agg(to_jsonb(t)-'display_order' order by id) from public.paid_tournaments t where id<>'671f995b-18bf-4c49-a706-caff6e580e19'), 'predictions',(select jsonb_agg(to_jsonb(g) order by tournament_id,slot) from public.paid_tournament_predictions g where tournament_id<>'671f995b-18bf-4c49-a706-caff6e580e19'), 'entries',(select jsonb_agg(to_jsonb(e) order by tournament_id,profile_id) from public.paid_tournament_entries e where tournament_id<>'671f995b-18bf-4c49-a706-caff6e580e19'), 'picks',(select jsonb_agg(to_jsonb(p) order by tournament_id,slot,profile_id) from public.paid_tournament_picks p where tournament_id<>'671f995b-18bf-4c49-a706-caff6e580e19'), 'orders',(select jsonb_agg(to_jsonb(o) order by id) from public.infinitepay_orders o where tournament_id is distinct from '671f995b-18bf-4c49-a706-caff6e580e19'::uuid), 'profiles',(select jsonb_agg(to_jsonb(p) order by id) from public.public_profiles p)) into after_snapshot;
 if after_snapshot is distinct from (select snapshot from kept_tournaments) then raise exception 'Other tournaments, profiles or payments changed'; end if;
end $$;
select 'PASS: restored 20 results/11 entries/220 picks/5 orders/4 audits; NicoTheGoat 11 pts; closed, public winner/private picks, ties/pending/future guarded; Champions first; unrelated data unchanged' as checks;
rollback;
