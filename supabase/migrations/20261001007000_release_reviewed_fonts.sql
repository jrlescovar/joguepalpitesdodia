begin;
-- Release the 34 approved fonts, while retaining Rubik Puddles as private.
alter table public.public_profiles drop constraint username_font_available;
update public.public_profiles set username_font=case username_font
 when 'preview-rubikglitch' then 'rubikglitch'
 when 'preview-rubikwetpaint' then 'rubikwetpaint'
 when 'preview-rubikdirt' then 'rubikdirt'
 when 'preview-rampartone' then 'rampartone'
 when 'preview-tiltprism' then 'tiltprism'
 when 'preview-shojumaru' then 'shojumaru'
 when 'preview-tradewinds' then 'tradewinds'
 when 'preview-sedgwickavedisplay' then 'sedgwickavedisplay'
 when 'preview-fugazone' then 'fugazone'
 when 'preview-reggaeone' then 'reggaeone'
 when 'preview-akronim' then 'akronim'
 when 'preview-alfaslabone' then 'alfaslabone'
 when 'preview-allertastencil' then 'allertastencil'
 when 'preview-arbutus' then 'arbutus'
 when 'preview-arizonia' then 'arizonia'
 when 'preview-barrio' then 'barrio'
 when 'preview-bigelowrules' then 'bigelowrules'
 when 'preview-bungeeshade' then 'bungeeshade'
 when 'preview-caesardressing' then 'caesardressing'
 when 'preview-kiranghaerang' then 'kiranghaerang'
 when 'preview-fascinateinline' then 'fascinateinline'
 when 'preview-fingerpaint' then 'fingerpaint'
 when 'preview-frederickathegreat' then 'frederickathegreat'
 when 'preview-hennypenny' then 'hennypenny'
 when 'preview-lacquer' then 'lacquer'
 when 'preview-rubikbeastly' then 'rubikbeastly'
 when 'preview-rubikmoonrocks' then 'rubikmoonrocks'
 when 'preview-ewert' then 'ewert'
 when 'preview-sancreek' then 'sancreek'
 when 'preview-megrim' then 'megrim'
 when 'preview-geostarfill' then 'geostarfill'
 when 'preview-kumaroneoutline' then 'kumaroneoutline'
 when 'preview-miltoniantattoo' then 'miltoniantattoo'
 when 'preview-rubikvinyl' then 'rubikvinyl'
 else 'normal' end
where username_font in ('preview-rubikglitch','preview-rubikwetpaint','preview-rubikdirt','preview-rampartone','preview-tiltprism','preview-shojumaru','preview-tradewinds','preview-sedgwickavedisplay','preview-fugazone','preview-reggaeone','preview-akronim','preview-alfaslabone','preview-allertastencil','preview-arbutus','preview-arizonia','preview-barrio','preview-bigelowrules','preview-bungeeshade','preview-caesardressing','preview-kiranghaerang','preview-fascinateinline','preview-fingerpaint','preview-frederickathegreat','preview-hennypenny','preview-lacquer','preview-rubikbeastly','preview-rubikmoonrocks','preview-ewert','preview-sancreek','preview-megrim','preview-geostarfill','preview-kumaroneoutline','preview-miltoniantattoo','preview-rubikvinyl','preview-diplomatasc','preview-yatraone','preview-asset','preview-biorhymeexpanded','preview-bokor','preview-bowlbyonesc','preview-changaone','preview-diplomata','preview-geostar','preview-rubikspraypaint');
alter table public.public_profiles add constraint username_font_available check(
 username_font in ('normal','quantico','blackopsone','audiowide','bebasneue','orbitron','creepster','luckiestguy','metalmania','amaticsc','kalam','permanentmarker','specialelite','rye','frijole','butcherman','eater','monocraft','dancingscript','marckscript','unifrakturcook','rubikglitch','rubikwetpaint','rubikdirt','rampartone','tiltprism','shojumaru','tradewinds','sedgwickavedisplay','fugazone','reggaeone','akronim','alfaslabone','allertastencil','arbutus','arizonia','barrio','bigelowrules','bungeeshade','caesardressing','kiranghaerang','fascinateinline','fingerpaint','frederickathegreat','hennypenny','lacquer','rubikbeastly','rubikmoonrocks','ewert','sancreek','megrim','geostarfill','kumaroneoutline','miltoniantattoo','rubikvinyl')
 or (player_id=1000001 and username_font='preview-rubikpuddles')
);
insert into public.box_style_catalog(style,rarity,item_kind,theme) values
 ('rubikglitch','mythic','font','classic'),
 ('rubikwetpaint','mythic','font','classic'),
 ('rubikdirt','epic','font','classic'),
 ('rampartone','mythic','font','classic'),
 ('tiltprism','mythic','font','classic'),
 ('shojumaru','epic','font','classic'),
 ('tradewinds','epic','font','classic'),
 ('sedgwickavedisplay','legendary','font','halloween'),
 ('fugazone','rare','font','classic'),
 ('reggaeone','epic','font','classic'),
 ('akronim','mythic','font','classic'),
 ('alfaslabone','rare','font','classic'),
 ('allertastencil','epic','font','classic'),
 ('arbutus','rare','font','classic'),
 ('arizonia','legendary','font','classic'),
 ('barrio','epic','font','classic'),
 ('bigelowrules','mythic','font','classic'),
 ('bungeeshade','epic','font','classic'),
 ('caesardressing','mythic','font','halloween'),
 ('kiranghaerang','mythic','font','classic'),
 ('fascinateinline','mythic','font','classic'),
 ('fingerpaint','mythic','font','classic'),
 ('frederickathegreat','mythic','font','halloween'),
 ('hennypenny','legendary','font','halloween'),
 ('lacquer','epic','font','classic'),
 ('rubikbeastly','epic','font','classic'),
 ('rubikmoonrocks','epic','font','halloween'),
 ('ewert','epic','font','halloween'),
 ('sancreek','mythic','font','classic'),
 ('megrim','mythic','font','classic'),
 ('geostarfill','epic','font','classic'),
 ('kumaroneoutline','mythic','font','classic'),
 ('miltoniantattoo','rare','font','classic'),
 ('rubikvinyl','legendary','font','halloween')
on conflict(style) do update set rarity=excluded.rarity,item_kind=excluded.item_kind,theme=excluded.theme;
update public.box_style_catalog set rarity='rare' where style='bebasneue' and item_kind='font';
create or replace function public.username_font_allowed(p_profile_id uuid,p_font text)
returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
 select case when left(p_font,8)='preview-' then
  p_font='preview-rubikpuddles' and p_profile_id=public.own_profile_id()
  and exists(select 1 from public.public_profiles where id=p_profile_id and player_id=1000001)
 else p_font='normal' or (
  exists(select 1 from public.box_style_catalog c where c.style=p_font and c.item_kind='font') and (
   exists(select 1 from public.public_profiles where id=p_profile_id and player_id=1000001)
   or exists(select 1 from public.box_inventory where profile_id=p_profile_id and kind='font' and style=p_font)
  )) end;
$$;
revoke all on function public.username_font_allowed(uuid,text) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
