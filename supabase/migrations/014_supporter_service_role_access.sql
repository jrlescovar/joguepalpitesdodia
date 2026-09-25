-- Allow the Supabase Edge Function's service role through the existing
-- PostgREST pre-request check when it writes subscription state.
grant execute on function public.check_api_request() to service_role;
