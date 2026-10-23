begin;

-- Retire both released and legacy IDs. Preserve all earned XP and other rewards.
update public.public_profiles set username_font='normal'
where username_font in ('unifrakturcook','preview-unifrakturcook');
delete from public.box_inventory where style in ('unifrakturcook','preview-unifrakturcook');
delete from public.box_openings where style in ('unifrakturcook','preview-unifrakturcook');
delete from public.player_mail where style in ('unifrakturcook','preview-unifrakturcook');
delete from public.box_style_catalog where style in ('unifrakturcook','preview-unifrakturcook');


-- Keep claimed milestones and XP repair receipts so rewards cannot be claimed again.
update public.level_drops set reward=(reward-'style') || '{"retired":true}'::jsonb
where status='claimed' and reward->>'style' in ('unifrakturcook','preview-unifrakturcook');
update public.level_drop_xp_repairs set previous_reward=(previous_reward-'style') || '{"retired":true}'::jsonb
where previous_reward->>'style' in ('unifrakturcook','preview-unifrakturcook');

do $$
begin
 if not exists(select 1 from pg_constraint where conrelid='public.public_profiles'::regclass and conname='retired_unifrakturcook_font') then
  alter table public.public_profiles add constraint retired_unifrakturcook_font
   check(username_font not in ('unifrakturcook','preview-unifrakturcook'));
 end if;
 if exists(select 1 from public.box_style_catalog where style in ('unifrakturcook','preview-unifrakturcook'))
 or exists(select 1 from public.box_inventory where style in ('unifrakturcook','preview-unifrakturcook'))
 or exists(select 1 from public.public_profiles where username_font in ('unifrakturcook','preview-unifrakturcook')) then
  raise exception 'UnifrakturCook retirement incomplete';
 end if;
end $$;
notify pgrst,'reload schema';
commit;
