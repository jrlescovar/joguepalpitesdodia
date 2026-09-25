begin;

-- Keep per-user request limiting, but return a valid PostgREST HTTP 429 error.
-- auth.uid() reads the current JWT claim reliably; anonymous calls keep an IP key.
create or replace function public.check_api_request()
returns void language plpgsql security definer set search_path = public, private, auth, pg_temp as $$
declare
  request_method text := current_setting('request.method',true);
  jwt_subject uuid := auth.uid();
  forwarded_ip text := split_part(coalesce(current_setting('request.headers',true)::jsonb->>'x-forwarded-for','unknown'),',',1);
  request_identity text;
  hits integer;
begin
  if request_method in ('GET','HEAD') or request_method is null or current_setting('transaction_read_only') = 'on' then return; end if;
  request_identity := case
    when jwt_subject is not null then 'user:' || jwt_subject::text
    else 'ip:' || encode(extensions.digest(forwarded_ip,'sha256'),'hex')
  end;

  insert into private.api_rate_limits(identity_key,window_started_at,request_count)
  values(request_identity,now(),1)
  on conflict(identity_key) do update set
    window_started_at=case when private.api_rate_limits.window_started_at < now()-interval '1 minute' then now() else private.api_rate_limits.window_started_at end,
    request_count=case when private.api_rate_limits.window_started_at < now()-interval '1 minute' then 1 else private.api_rate_limits.request_count+1 end
  returning request_count into hits;

  if hits > 120 then
    raise sqlstate 'PT429' using message='Muitas requisições. Aguarde um minuto e tente novamente.';
  end if;
end;
$$;

notify pgrst,'reload schema';
commit;
