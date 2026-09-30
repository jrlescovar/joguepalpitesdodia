begin;
-- Extend the private owner font allowlist from ten to thirty-five previews.

-- Private previews are accepted only on the owner's profile, never in loot pools.
alter table public.public_profiles drop constraint username_font_available;
alter table public.public_profiles add constraint username_font_available check(
 username_font in ('normal','blackopsone','audiowide','bebasneue','orbitron','creepster','luckiestguy','amaticsc','kalam','permanentmarker','specialelite','monocraft','dancingscript','metalmania','rye','frijole','quantico','eater','butcherman','marckscript','unifrakturcook')
 or (player_id=1000001 and username_font in ('preview-rubikglitch','preview-rubikwetpaint','preview-rubikdirt','preview-rampartone','preview-tiltprism','preview-shojumaru','preview-tradewinds','preview-sedgwickavedisplay','preview-yatraone','preview-fugazone','preview-reggaeone','preview-akronim','preview-alfaslabone','preview-allertastencil','preview-arbutus','preview-arizonia','preview-asset','preview-barrio','preview-bigelowrules','preview-biorhymeexpanded','preview-bokor','preview-bowlbyonesc','preview-bungeeshade','preview-caesardressing','preview-changaone','preview-kiranghaerang','preview-diplomata','preview-diplomatasc','preview-fascinateinline','preview-fingerpaint','preview-frederickathegreat','preview-hennypenny','preview-lacquer','preview-rubikbeastly','preview-rubikmoonrocks'))
);

create or replace function public.username_font_allowed(p_profile_id uuid,p_font text)
returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
 select case when left(p_font,8)='preview-' then
  p_font in ('preview-rubikglitch','preview-rubikwetpaint','preview-rubikdirt','preview-rampartone','preview-tiltprism','preview-shojumaru','preview-tradewinds','preview-sedgwickavedisplay','preview-yatraone','preview-fugazone','preview-reggaeone','preview-akronim','preview-alfaslabone','preview-allertastencil','preview-arbutus','preview-arizonia','preview-asset','preview-barrio','preview-bigelowrules','preview-biorhymeexpanded','preview-bokor','preview-bowlbyonesc','preview-bungeeshade','preview-caesardressing','preview-changaone','preview-kiranghaerang','preview-diplomata','preview-diplomatasc','preview-fascinateinline','preview-fingerpaint','preview-frederickathegreat','preview-hennypenny','preview-lacquer','preview-rubikbeastly','preview-rubikmoonrocks') and p_profile_id=public.own_profile_id()
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
