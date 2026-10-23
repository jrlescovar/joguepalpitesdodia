begin;

-- Retire both released and legacy IDs. Preserve all earned XP and other rewards.
update public.public_profiles set username_font='normal'
where username_font in ('butcherman','preview-butcherman');
delete from public.box_inventory where style in ('butcherman','preview-butcherman');
delete from public.box_openings where style in ('butcherman','preview-butcherman');
delete from public.player_mail where style in ('butcherman','preview-butcherman');
delete from public.box_style_catalog where style in ('butcherman','preview-butcherman');


-- Keep claimed milestones and XP repair receipts so rewards cannot be claimed again.
update public.level_drops set reward=(reward-'style') || '{"retired":true}'::jsonb
where status='claimed' and reward->>'style' in ('butcherman','preview-butcherman');
update public.level_drop_xp_repairs set previous_reward=(previous_reward-'style') || '{"retired":true}'::jsonb
where previous_reward->>'style' in ('butcherman','preview-butcherman');

do $$
begin
 if not exists(select 1 from pg_constraint where conrelid='public.public_profiles'::regclass and conname='retired_butcherman_font') then
  alter table public.public_profiles add constraint retired_butcherman_font
   check(username_font not in ('butcherman','preview-butcherman'));
 end if;
 if exists(select 1 from public.box_style_catalog where style in ('butcherman','preview-butcherman'))
 or exists(select 1 from public.box_inventory where style in ('butcherman','preview-butcherman'))
 or exists(select 1 from public.public_profiles where username_font in ('butcherman','preview-butcherman')) then
  raise exception 'Assombrada retirement incomplete';
 end if;
end $$;
update public.box_style_catalog set rarity='epic' where style in ('specialelite','rye') and item_kind='font';
update public.box_openings set rarity='epic' where style in ('specialelite','rye') and kind='font';
do $$ begin
 if (select count(*) from public.box_style_catalog where style in ('specialelite','rye') and item_kind='font' and rarity='epic')<>2 then
  raise exception 'Epic font catalogue update failed';
 end if;
end $$;
notify pgrst,'reload schema';
commit;
