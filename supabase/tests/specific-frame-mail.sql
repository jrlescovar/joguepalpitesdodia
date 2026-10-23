-- Run after the specific frame mail migration. All fixtures roll back.
begin;
create function public.frame_mail_test_credit_guard() returns trigger language plpgsql as $$begin
 if current_setting('frame.test_fail',true)='on' then raise exception 'test_credit_failure';end if;
 return new;
end $$;
create trigger frame_mail_test_credit_guard before insert on public.box_inventory for each row execute function public.frame_mail_test_credit_guard();
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); subject_a uuid:=gen_random_uuid(); subject_b uuid:=gen_random_uuid(); owner_subject uuid:=gen_random_uuid();
 before_profile jsonb; result jsonb; denied boolean; table_name text;
begin
 insert into public.public_profiles(id,player_id,username,avatar_color) values(a,9900201,'framemailqa1','#3b82f6'),(b,9900202,'framemailqa2','#3b82f6');
 insert into public.private_profiles(profile_id,auth_user_id,email) values(a,subject_a,'framemailqa1@example.invalid'),(b,subject_b,'framemailqa2@example.invalid');
 select to_jsonb(p) into before_profile from public.public_profiles p where id=a;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',subject_a,'email','framemailqa1@example.invalid')::text,true);
 denied:=false;
 begin perform public.admin_grant_frame_mail(a,'lab-blue-9'); exception when others then if sqlerrm='Acesso restrito.' then denied:=true; else raise; end if; end;
 if not denied then raise exception 'Non-admin grant was permitted'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner_subject,'email',(select owner_email from public.app_config where singleton))::text,true);
 denied:=false;
 begin perform public.admin_grant_frame_mail(a,'missing-style'); exception when others then if sqlerrm='Moldura inválida.' then denied:=true; else raise; end if; end;
 if not denied then raise exception 'Invalid frame grant was permitted'; end if;
 perform public.admin_grant_frame_mail(a,'lab-blue-9');
 perform public.admin_grant_frame_mail(a,'lab-blue-9');
 if (select count(*) from public.player_mail where profile_id=a and kind='frame')<>1 then raise exception 'Grant retry duplicated mail'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',subject_b)::text,true);
 perform public.receive_mail('frame:lab-blue-9');
 if exists(select 1 from public.box_inventory where profile_id=b) or not exists(select 1 from public.player_mail where profile_id=a and kind='frame') then raise exception 'Cross-player claim failed'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',subject_a)::text,true);
 result:=public.get_mailbox();
 if result<>jsonb_build_array(jsonb_build_object('kind','frame:lab-blue-9','style','lab-blue-9','quantity',1)) then raise exception 'Frame mailbox payload mismatch: %',result; end if;
 perform public.receive_mail('frame:lab-blue-9');
 perform public.receive_mail('frame:lab-blue-9');
 if (select count(*) from public.box_inventory where profile_id=a)<>1 or not exists(select 1 from public.box_inventory where profile_id=a and kind='frame' and style='lab-blue-9') then raise exception 'Frame credit/retry incorrect'; end if;
 if exists(select 1 from public.player_mail where profile_id=a) then raise exception 'Claimed mail was retained'; end if;
 if (select to_jsonb(p) from public.public_profiles p where id=a)<>before_profile then raise exception 'Frame changed equipped style, XP, or profile'; end if;
 -- Expired frame is removed without inventory credit.
 insert into public.player_mail(profile_id,kind,style,quantity,created_at) values(b,'frame','lab-blue-9',1,now()-interval '7 days');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',subject_b)::text,true);
 perform public.receive_mail('frame:lab-blue-9');
 if exists(select 1 from public.player_mail where profile_id=b) or exists(select 1 from public.box_inventory where profile_id=b) then raise exception 'Expired frame was credited or retained'; end if;
 -- Atomic rollback when credit fails.
 insert into public.player_mail(profile_id,kind,style,quantity) values(b,'frame','lab-blue-9',1);
 perform set_config('frame.test_fail','on',true);
 denied:=false;
 begin perform public.receive_mail('frame:lab-blue-9'); exception when others then if sqlerrm='test_credit_failure' then denied:=true;else raise;end if;end;
 if not denied or not exists(select 1 from public.player_mail where profile_id=b and kind='frame') then raise exception 'Failed credit consumed mail'; end if;
 perform set_config('frame.test_fail','off',true);
 perform public.receive_mail('frame:lab-blue-9');
 -- Existing delivery kinds still group, credit, delete, and do not double-credit.
 insert into public.player_mail(profile_id,kind,quantity) values(a,'drop',2),(a,'classic',2),(a,'font',2),(a,'halloween',2),(a,'premium',2);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',subject_a)::text,true);
 if jsonb_array_length(public.get_mailbox())<>5 then raise exception 'Legacy mailbox grouping changed'; end if;
 perform public.receive_mail('drop');perform public.receive_mail('drop');
 if (select count(*) from public.level_drops where profile_id=a)<>2 then raise exception 'Legacy drop credit changed'; end if;
 foreach table_name in array array['classic','font','halloween'] loop perform public.receive_mail(table_name); perform public.receive_mail(table_name); end loop;
 if (select balance from public.box_balances where profile_id=a)<>2 or (select balance from public.font_box_balances where profile_id=a)<>2 or (select balance from public.halloween_box_balances where profile_id=a)<>2 then raise exception 'Legacy box credit changed'; end if;
 perform public.receive_mail('premium');perform public.receive_mail('premium');
 if (select grant_ends_at from public.pass_grants where profile_id=a)<>now()+interval '2 days' then raise exception 'Legacy Premium credit changed'; end if;
 if exists(select 1 from public.player_mail where profile_id=a) then raise exception 'Legacy claim deletion changed'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner_subject,'email',(select owner_email from public.app_config where singleton))::text,true);
 result:=public.admin_grant_frame_mail(a,'lab-blue-9');
 if not (result->>'alreadyOwned')::boolean or exists(select 1 from public.player_mail where profile_id=a and kind='frame') then raise exception 'Owned frame queued again'; end if;
 if not has_function_privilege('authenticated','public.admin_grant_frame_mail(uuid,text)','execute') or has_function_privilege('anon','public.admin_grant_frame_mail(uuid,text)','execute') then raise exception 'Admin RPC grants incorrect';end if;
end $$;
select jsonb_build_object('passed',true,'checks','role checks, catalog validation, grouping, frame-only claim, replay, cross-player isolation, expiry, atomic failure, old deliveries, unchanged profile') frame_mail_test;
rollback;
