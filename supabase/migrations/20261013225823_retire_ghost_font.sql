begin;

update public.public_profiles set username_font='normal',updated_at=now()
where username_font in ('rubikvinyl','preview-rubikvinyl');
delete from public.box_inventory where kind='font' and style in ('rubikvinyl','preview-rubikvinyl');
delete from public.player_mail where style in ('rubikvinyl','preview-rubikvinyl');
update public.box_style_catalog set theme='retired' where item_kind='font' and style in ('rubikvinyl','preview-rubikvinyl');

-- Keep opening receipts, XP, balances and claimed milestones intact. Historical
-- request IDs must remain consumed so retrying an old opening cannot spend again.
update public.level_drops set reward=(reward-'style')||'{"retired":true}'::jsonb
where status='claimed' and reward->>'style' in ('rubikvinyl','preview-rubikvinyl');
update public.level_drop_xp_repairs set previous_reward=(previous_reward-'style')||'{"retired":true}'::jsonb
where previous_reward->>'style' in ('rubikvinyl','preview-rubikvinyl');

do $$declare definition text;begin
 definition:=pg_get_functiondef('public.username_font_allowed(uuid,text)'::regprocedure);
 if position('c.theme<>''retired''' in definition)=0 then
  if position('c.style=p_font and c.item_kind=''font''' in definition)=0 then raise exception 'Unexpected font eligibility implementation';end if;
  execute replace(definition,'c.style=p_font and c.item_kind=''font''','c.style=p_font and c.item_kind=''font'' and c.theme<>''retired''');
 end if;
 if not exists(select 1 from pg_constraint where conrelid='public.public_profiles'::regclass and conname='retired_ghost_font') then
  alter table public.public_profiles add constraint retired_ghost_font
   check(username_font not in ('rubikvinyl','preview-rubikvinyl'));
 end if;
 if exists(select 1 from public.box_style_catalog where theme<>'retired' and item_kind='font' and style in ('rubikvinyl','preview-rubikvinyl'))
  or exists(select 1 from public.box_inventory where kind='font' and style in ('rubikvinyl','preview-rubikvinyl'))
  or exists(select 1 from public.public_profiles where username_font in ('rubikvinyl','preview-rubikvinyl'))
  then raise exception 'Ghost retirement incomplete';end if;
end;$$;
notify pgrst,'reload schema';
commit;
