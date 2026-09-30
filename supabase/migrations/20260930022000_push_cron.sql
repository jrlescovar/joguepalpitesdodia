create extension if not exists pg_net with schema extensions;

select cron.schedule('push-palpites-five-minutes','*/5 * * * *',
  $job$
  select net.http_post(
    url := 'https://kvvctmkxdvgdashxwpjb.supabase.co/functions/v1/push-dispatch',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'x-push-schedule-secret',(select decrypted_secret from vault.decrypted_secrets where name='push_dispatch_secret')
    ),
    body := '{"mode":"scheduled"}'::jsonb
  );
  $job$
);
