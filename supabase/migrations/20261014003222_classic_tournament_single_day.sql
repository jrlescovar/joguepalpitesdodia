begin;
do $$declare definition text;begin
 select pg_get_constraintdef(oid) into definition from pg_constraint where conrelid='public.paid_tournaments'::regclass and conname='paid_tournaments_check';
 alter table public.paid_tournaments drop constraint paid_tournaments_check;
 execute 'alter table public.paid_tournaments add constraint paid_tournaments_check check (('||substring(definition from 8 for length(definition)-8)||') or (metric=''classic'' and ends_at>starts_at and (ends_at at time zone ''America/Sao_Paulo'')::date=(starts_at at time zone ''America/Sao_Paulo'')::date))';
end $$;
commit;
