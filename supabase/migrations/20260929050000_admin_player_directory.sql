begin;
create function public.get_admin_players(p_search text default '',p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,auth,pg_temp as $$
declare query text:=lower(trim(coalesce(p_search,''))); total integer; pages integer; page integer;
begin
 if not public.is_admin() then raise exception 'Somente o proprietário pode consultar jogadores.'; end if;
 query:=left(regexp_replace(query,'^[@#]',''),100);
 select count(*) into total from public.public_profiles where query='' or strpos(lower(username),query)>0 or player_id::text=query;
 pages:=greatest(1,(total+4)/5);page:=least(pages,greatest(1,coalesce(p_page,1)));
 return jsonb_build_object('total',total,'pages',pages,'page',page,'players',(
 select coalesce(jsonb_agg(public.get_public_profile(p.id) order by p.player_id),'[]'::jsonb) from (
 select id,player_id from public.public_profiles where query='' or strpos(lower(username),query)>0 or player_id::text=query order by player_id limit 5 offset (page-1)*5) p));
end;$$;
revoke all on function public.get_admin_players(text,integer) from public,anon,authenticated;
grant execute on function public.get_admin_players(text,integer) to authenticated;
commit;
