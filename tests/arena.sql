-- Run inside a transaction; no production player data is changed permanently.
begin;
do $$
declare d date:=public.battle_today(); a uuid; b uuid; payload jsonb; expected integer; snapshot text;
begin
 select profile_id into a from public.arena_entries where day_id=d order by seed limit 1;
 if (select count(*) from public.arena_entries where day_id=d)<>least(10,(select count(*) from public.public_profiles)) then raise exception 'Top ten count failed'; end if;
 if exists(select 1 from public.arena_entries e join (select id,row_number() over(order by rank_points desc,player_id) seed from public.public_profiles) p on p.id=e.profile_id where e.day_id=d and e.seed<>p.seed) then raise exception 'Initial top ten ordering failed'; end if;
 select sum(coalesce((o.value->>'rankPoints')::integer,0)) into expected from public.picks k join public.predictions g on g.day_id=k.prediction_day and g.slot=k.slot cross join lateral jsonb_array_elements(g.options) o(value) where k.prediction_day=d and k.profile_id=a and k.status='green' and o.value->>'id'=k.option_id;
 if (select points from public.arena_entries where day_id=d and profile_id=a)<>coalesce(expected,0) then raise exception 'Today points failed'; end if;
 select md5(jsonb_agg(to_jsonb(e) order by seed)::text) into snapshot from public.arena_entries e where day_id=d;
 update public.public_profiles set rank_points=rank_points+9999 where id=a;
 perform public.ensure_arena_round(d);
 if snapshot<>(select md5(jsonb_agg(to_jsonb(e) order by seed)::text) from public.arena_entries e where day_id=d) then raise exception 'Eligibility changed midround'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',(select auth_user_id from public.private_profiles where profile_id=a))::text,true);
 payload:=public.get_arena();
 if not (payload->>'qualified')::boolean or jsonb_array_length(payload->'players')<>10 then raise exception 'Participant read failed'; end if;
 select p.profile_id into b from public.private_profiles p where not exists(select 1 from public.arena_entries where day_id=d and profile_id=p.profile_id) limit 1;
 if b is not null then
 perform set_config('request.jwt.claims',jsonb_build_object('sub',(select auth_user_id from public.private_profiles where profile_id=b))::text,true);
 payload:=public.get_arena();
 if (payload->>'qualified')::boolean or jsonb_array_length(payload->'players')<>10 then raise exception 'Spectator read failed'; end if;
 end if;
 -- Finalize only within this rollback test. Existing settlement triggers are
 -- disabled so no unrelated battle accounting is executed by the fixture.
 alter table public.predictions disable trigger user;
 update public.predictions set status='settled' where day_id=d;
 perform public.refresh_arena_round(d);
 select profile_id into a from public.arena_entries where day_id=d order by points desc,greens desc,seed limit 1;
 if (select winner_id from public.arena_rounds where day_id=d)<>a or not exists(select 1 from public.arena_crown where profile_id=a and won_on=d) then raise exception 'Champion failed'; end if;
 update public.arena_entries set points=points+99999 where day_id=d and seed=10;
 perform public.refresh_arena_round(d);
 if (select winner_id from public.arena_rounds where day_id=d)<>a then raise exception 'Finalized winner changed'; end if;
 perform set_config('request.jwt.claims','{}',true);
 begin
 perform public.get_arena(); raise exception 'Anonymous read accepted';
 exception when others then if sqlerrm='Anonymous read accepted' then raise; end if; end;
 if has_function_privilege('authenticated','public.ensure_arena_round(date)','execute') or has_table_privilege('authenticated','public.arena_entries','insert') then raise exception 'Direct mutations allowed'; end if;
end;$$;
rollback;
