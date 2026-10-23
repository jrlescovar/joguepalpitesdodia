-- Run after migration inside a transaction that ends in ROLLBACK.
do $$
declare counts jsonb;
begin
 select jsonb_object_agg(chosen,n) into counts from (
  select public.bot_ranked_option('[{"id":"easy","rankPoints":15},{"id":"none","rankPoints":360},{"id":"risk","rankPoints":30}]',i/10000.0) as chosen,count(*) n
  from generate_series(0,9999) i group by chosen
 ) t;
 if counts ? 'none' or (counts->>'easy')::int not between 6200 and 6400 or (counts->>'risk')::int not between 3600 and 3800 then raise exception 'Chelsea risk weights wrong: %',counts; end if;
 select jsonb_object_agg(chosen,n) into counts from (
  select public.bot_ranked_option('[{"id":"five","rankPoints":5},{"id":"ten","rankPoints":10},{"id":"forty","rankPoints":40},{"id":"sixty","rankPoints":60}]',i/10000.0) as chosen,count(*) n
  from generate_series(0,9999) i group by chosen
 ) t;
 if (counts->>'five')::int<=(counts->>'ten')::int or (counts->>'ten')::int<=(counts->>'forty')::int or (counts->>'forty')::int<=(counts->>'sixty')::int or coalesce((counts->>'sixty')::int,0)<=0 then raise exception 'Safe/risky variation wrong: %',counts; end if;
 if public.bot_ranked_option('[{"id":"hundred","rankPoints":100},{"id":"above","rankPoints":101}]',0.999999)<>'hundred' then raise exception '100-point boundary wrong'; end if;
 if public.bot_ranked_option('[{"id":"x","rankPoints":120},{"id":"y","rankPoints":300}]',0.5) is not null then raise exception 'All-excluded event must be skipped'; end if;
 if public.bot_ranked_option('[]',0.5) is not null or public.bot_ranked_option('[{"id":"x","rankPoints":5}]',1) is not null then raise exception 'Invalid/empty draw not rejected'; end if;
 if public.bot_ranked_option('[{"id":"x"},{"id":"y"}]',0.2)<>'x' or public.bot_ranked_option('[{"id":"x"},{"id":"y"}]',0.8)<>'y' then raise exception 'Missing points fallback wrong'; end if;
 if public.bot_ranked_option('[{"id":"easy","rankPoints":5},{"id":"risk","rankPoints":50},{"id":"none","rankPoints":360}]',0,'easy')<>'risk' then raise exception 'Diversity alternative wrong'; end if;
 if has_function_privilege('authenticated','public.bot_ranked_option(jsonb,double precision,text)','EXECUTE') or has_function_privilege('anon','public.bot_ranked_option(jsonb,double precision,text)','EXECUTE') then raise exception 'Private helper exposed'; end if;
end;
$$;
select 'PASS: deterministic 20000-draw distributions, safe/risky variation, 100 ceiling, all-excluded skip and private access' as result;
