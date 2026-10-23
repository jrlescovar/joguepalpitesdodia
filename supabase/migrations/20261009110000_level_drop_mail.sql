begin;
alter table public.level_drops add column received_at timestamptz;
update public.level_drops set received_at=now() where tier>0 or clicks_left<5 or status<>'playing';
create function public.receive_level_drop(p_drop_id uuid) returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare target uuid:=public.own_profile_id(); d public.level_drops%rowtype;
begin
 if not exists(select 1 from public.public_profiles where id=target and player_id=1000001 and lower(username)='zaotips') then raise exception 'Prévia exclusiva do zaotips.'; end if;
 update public.level_drops set received_at=coalesce(received_at,now()) where id=p_drop_id and profile_id=target returning * into d;
 if not found then raise exception 'Mensagem não encontrada.'; end if;
 return to_jsonb(d);
end $$;
create function public.require_received_level_drop() returns trigger language plpgsql as $$ begin
 if old.received_at is null and (new.tier<>old.tier or new.clicks_left<>old.clicks_left or new.status<>old.status) then raise exception 'Resgate este drop no correio primeiro.'; end if;
 return new;
end $$;
create trigger level_drop_mail_guard before update on public.level_drops for each row execute function public.require_received_level_drop();
revoke all on function public.receive_level_drop(uuid) from public,anon;
grant execute on function public.receive_level_drop(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
select count(*) from public.level_drops where received_at is null;
