begin;
do $$
declare payload jsonb; first_id bigint; second_id bigint; total integer;
begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub','00000000-0000-0000-0000-000000000001','email',(select owner_email from public.app_config where singleton))::text,true);
 select count(*) into total from public.public_profiles;
 payload:=public.get_admin_players('',1);
 if (payload->>'total')::integer<>total or jsonb_array_length(payload->'players')<>least(5,total) then raise exception 'Page size/count failed'; end if;
 first_id:=(payload->'players'->0->>'playerId')::bigint;
 payload:=public.get_admin_players('',2);
 second_id:=(payload->'players'->0->>'playerId')::bigint;
 if total>5 and second_id<=first_id then raise exception 'Pagination repeated first page'; end if;
 payload:=public.get_admin_players('#'||first_id::text,1);
 if jsonb_array_length(payload->'players')<>1 or (payload->'players'->0->>'playerId')::bigint<>first_id then raise exception 'ID search failed'; end if;
 payload:=public.get_admin_players('',999999);
 if (payload->>'page')::integer<>(payload->>'pages')::integer then raise exception 'Page clamp failed'; end if;
 if exists(select 1 from jsonb_array_elements(payload->'players') p where p ? 'email' or p ? 'balance') then raise exception 'Directory leaked private data'; end if;
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-000000000001","email":"player@example.com"}',true);
 begin
 perform public.get_admin_players('',1);raise exception 'Nonadmin directory access allowed';
 exception when others then if sqlerrm='Nonadmin directory access allowed' then raise; end if;end;
end;$$;
rollback;
select jsonb_build_object('admin_directory_tests_passed',true);
