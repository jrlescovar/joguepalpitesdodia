begin;
update public.public_profiles set username_font='normal',updated_at=now() where username_font in ('bigelowrules','preview-bigelowrules','akronim','preview-akronim','arizonia','preview-arizonia','tiltprism','preview-tiltprism');
delete from public.box_inventory where kind='font' and style in ('bigelowrules','preview-bigelowrules','akronim','preview-akronim','arizonia','preview-arizonia','tiltprism','preview-tiltprism');
delete from public.player_mail where style in ('bigelowrules','preview-bigelowrules','akronim','preview-akronim','arizonia','preview-arizonia','tiltprism','preview-tiltprism');
update public.box_style_catalog set theme='retired' where item_kind='font' and style in ('bigelowrules','preview-bigelowrules','akronim','preview-akronim','arizonia','preview-arizonia','tiltprism','preview-tiltprism');
update public.level_drops set reward=(reward-'style')||'{"retired":true}'::jsonb where reward->>'style' in ('bigelowrules','preview-bigelowrules','akronim','preview-akronim','arizonia','preview-arizonia','tiltprism','preview-tiltprism');
update public.level_drop_xp_repairs set previous_reward=(previous_reward-'style')||'{"retired":true}'::jsonb where previous_reward->>'style' in ('bigelowrules','preview-bigelowrules','akronim','preview-akronim','arizonia','preview-arizonia','tiltprism','preview-tiltprism');
alter table public.public_profiles add constraint removed_four_fonts check(username_font not in ('bigelowrules','preview-bigelowrules','akronim','preview-akronim','arizonia','preview-arizonia','tiltprism','preview-tiltprism'));
commit;
