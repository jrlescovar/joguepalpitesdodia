import { useId } from 'react';
import { rankTier } from './rankTiers';
import './rankEmblems.css';

const materials = {
 bronze:['#ffe0b2','#b96f3a','#5a301d','#e8a16a'],
 silver:['#ffffff','#bacbdb','#46576b','#e4edf5'],
 gold:['#fff4bf','#f3b935','#754416','#ffe18a'],
 platinum:['#e4fff9','#66d7d0','#16545e','#a7fff0'],
 diamond:['#f0dcff','#9860df','#321458','#cfadff'],
 emerald:['#c6fff1','#15d297','#075446','#79ffcf'],
 sapphire:['#d5eeff','#2678ff','#092878','#8dc7ff'],
 legendary:['#ffe3c1','#fa4654','#691225','#ff9684'],
 elite:['#fff0ba','#f8a043','#72401b','#ffd990'],
 master:['#ffffff','#d7dee7','#535d69','#ffffff'],
} as const;

export default function RankEmblem({ points }: { points: number }) {
  const tier = rankTier(points);
  const emblemKey = tier.key === 'master' ? 'elite' : tier.key === 'elite' ? 'master' : tier.key;
  const id = 'rank-'+useId().replace(/:/g,'');
  const [light,base,dark,accent]=materials[emblemKey];
  const paint=(name:string)=>`url(#${id}-${name})`;
  return <span className={`rank-emblem rank-emblem-v2 rank-emblem-${emblemKey}`} role="img" aria-label={`Rank ${tier.name}`}>
    <svg viewBox="0 0 64 64" fill="none" aria-hidden="true" style={{'--rank-metal':paint('metal'),'--rank-core':paint('core'),'--rank-gem':paint('gem'),'--rank-edge':paint('edge')} as React.CSSProperties}>
      <defs>
        <linearGradient id={id+'-metal'} x1="8" y1="3" x2="53" y2="61" gradientUnits="userSpaceOnUse"><stop stopColor={light}/><stop offset=".16" stopColor={base}/><stop offset=".31" stopColor={light}/><stop offset=".48" stopColor={dark}/><stop offset=".68" stopColor={base}/><stop offset=".84" stopColor={dark}/><stop offset="1" stopColor={accent}/></linearGradient>
        <linearGradient id={id+'-core'} x1="13" y1="7" x2="48" y2="57" gradientUnits="userSpaceOnUse"><stop stopColor="#333c48"/><stop offset=".46" stopColor="#111820"/><stop offset="1" stopColor="#070b12"/></linearGradient>
        <linearGradient id={id+'-gem'} x1="17" y1="15" x2="44" y2="49" gradientUnits="userSpaceOnUse"><stop stopColor={light}/><stop offset=".35" stopColor={base}/><stop offset=".72" stopColor={dark}/><stop offset="1" stopColor={accent}/></linearGradient>
        <linearGradient id={id+'-edge'} x1="14" y1="10" x2="45" y2="53" gradientUnits="userSpaceOnUse"><stop stopColor={light}/><stop offset=".44" stopColor={base}/><stop offset="1" stopColor={dark}/></linearGradient>
        <linearGradient id={id+'-gold'} x1="20" y1="16" x2="43" y2="44" gradientUnits="userSpaceOnUse"><stop stopColor="#fff5c7"/><stop offset=".4" stopColor="#ffd36b"/><stop offset="1" stopColor="#a26720"/></linearGradient>
        {emblemKey==='emerald'&&<>
          <linearGradient id={id+'-emerald-table'} x1="25" y1="22" x2="40" y2="42" gradientUnits="userSpaceOnUse"><stop stopColor="#60edb3"/><stop offset=".45" stopColor="#16b97f"/><stop offset="1" stopColor="#087553"/></linearGradient>
          <linearGradient id={id+'-emerald-left'} x1="18" y1="20" x2="26" y2="45" gradientUnits="userSpaceOnUse"><stop stopColor="#8effd2"/><stop offset="1" stopColor="#139a6d"/></linearGradient>
          <linearGradient id={id+'-emerald-right'} x1="40" y1="18" x2="47" y2="44" gradientUnits="userSpaceOnUse"><stop stopColor="#0c9c6b"/><stop offset="1" stopColor="#043c33"/></linearGradient>
        </>}

      </defs>
      {emblemKey === 'bronze' && <>
        <path d="M32 4 53 16v25L32 60 11 41V16Z" fill={paint('core')} stroke={paint('metal')} strokeWidth="2.5" strokeLinejoin="round"/>
        <path d="m16 19 16-9 16 9v19L32 53 16 38Z" stroke={paint('edge')} strokeWidth="1"/>
        <path d="m32 15 10 17-10 18-10-18Z" fill={paint('gem')} stroke={light} strokeWidth=".6"/>
        <path d="m32 15-10 17 10 3Z" fill="#f4ba80"/>
        <path d="m32 15 10 17-10 3Z" fill="#b96936"/>
        <path d="m22 32 10 3v15Z" fill="#9e512b"/>
        <path d="m42 32-10 3v15Z" fill="#512b1c"/>
        <path d="m17 26 5 6-5 6m30-12-5 6 5 6" stroke={paint('metal')} strokeWidth="2" strokeLinejoin="miter"/>
      </>}
      {emblemKey === 'silver' && <>
        <path d="M32 4 55 17l-5 28-18 15-18-15-5-28Z" fill={paint('core')} stroke={paint('metal')} strokeWidth="2.5" strokeLinejoin="round"/>
        <path d="m32 11 16 10-3 20-13 11-13-11-3-20Z" stroke={paint('edge')} strokeWidth="1"/>
        <path d="m17 21 15 9 15-9-2 10-13 9-13-9Z" fill={paint('metal')}/>
        <path d="m19 35 13 8 13-8-2 8-11 9-11-9Z" fill={paint('metal')}/>
        <path d="m17 21 15 9v5l-13-8Zm2 14 13 8v4l-11-7Z" fill="#f1f7ff"/>
        <path d="m47 21-15 9v5l13-8Zm-2 14-13 8v4l11-7Z" fill="#6e829a"/>
        <path d="m32 12 5 6-5 6-5-6Z" fill={paint('gem')}/>
      </>}
      {emblemKey === 'gold' && <>
        <path d="M32 3 54 13v28L32 61 10 41V13Z" fill={paint('core')} stroke={paint('metal')} strokeWidth="2.5" strokeLinejoin="round"/>
        <path d="m32 10 15 8v20L32 53 17 38V18Z" stroke={paint('edge')} strokeWidth="1"/>
        <path d="m19 19 13 8 13-8v8l-13 8-13-8Zm0 13 13 8 13-8v7l-13 9-13-9Zm5 13 8 5 8-5-8 11Z" fill={paint('gold')}/>
        <path d="m19 19 13 8v4l-13-8Zm0 13 13 8v4l-13-8Zm5 13 8 5v6Z" fill="#fff0a8"/>
        <path d="m45 19-13 8v4l13-8Zm0 13-13 8v4l13-8Zm-5 13-8 5v6Z" fill="#c2841e"/>
        <path d="m32 10 4 5-4 5-4-5Z" fill="#ffdc70"/>
      </>}
      {emblemKey === 'platinum' && <>
        <path d="M22 5h20l16 27-16 27H22L6 32Z" fill={paint('core')} stroke={paint('metal')} strokeWidth="2.2" strokeLinejoin="round"/>
        <path d="M25 11h14l12 21-12 21H25L13 32Z" stroke={paint('edge')} strokeWidth="1"/>
        <path d="m32 12 5 13 10-8-8 11 13 4-13 5 8 10-10-7-5 13-5-13-10 7 7-10-12-5 12-4-7-11 10 8Z" fill={paint('metal')} stroke="#c6fff5" strokeWidth=".5" strokeLinejoin="round"/>
        <path d="m32 12-5 13 5 7 5-7Zm-20 20 12 5 8-5-8-4Z" fill="#c3fff3"/>
        <path d="m52 32-13-4-7 4 7 5ZM32 53l5-13-5-8-5 8Z" fill="#258e91"/>
        <path d="m32 24 7 8-7 9-7-9Z" fill="#123e4d" stroke="#a6f7e5" strokeWidth=".8"/>
        <path d="m32 27-4 5 4 5 4-5Z" fill="#8bffe0"/>
        <path d="m32 27-4 5h4Z" fill="#e6fff8"/>
      </>}
      {emblemKey === 'emerald' && <>
        <path d="M32 3 53 20 48 45 32 61 16 45 11 20Z" fill={paint('core')} stroke={paint('metal')} strokeWidth="2" strokeLinejoin="round"/>
        <path d="m8 25 3 16 9 11M56 25l-3 16-9 11" stroke={paint('edge')} strokeWidth="2.5" strokeLinecap="square"/>
        <path d="m32 9 16 14-5 19-11 13-11-13-5-19Z" fill="#063e30" stroke="#a9ffe0" strokeWidth=".8" strokeLinejoin="round"/>
        <path d="m32 9-16 14 10 2 6-9Z" fill="#a4ffda"/>
        <path d="m32 9 16 14-10 2-6-9Z" fill="#37dba2"/>
        <path d="m16 23 5 19 11 13-6-30Z" fill={paint('emerald-left')}/>
        <path d="m48 23-5 19-11 13 6-30Z" fill={paint('emerald-right')}/>
        <path d="m32 16 6 9-2 13-4 9-4-9-2-13Z" fill={paint('emerald-table')}/>
        <path d="m26 25 6 5 6-5-6-9Z" fill="#57edb7"/>
        <path d="m26 25 6 5v17l-4-9Z" fill="#20c58d"/>
        <path d="m38 25-6 5v17l4-9Z" fill="#08794e"/>
        <path d="m21 42 7-4 4 17Z" fill="#0a9567"/>
        <path d="m43 42-7-4-4 17Z" fill="#064e39"/>
        <path d="m32 9-16 14 5 19M16 23l10 2 6-9M26 25l6 5 6-5M32 47v8" stroke="#ccffec" strokeWidth=".8" strokeLinecap="round" opacity=".8"/>
      </>}
      {emblemKey === 'sapphire' && <>
        <path d="m32 3 21 13 4 23-25 22L7 39l4-23Z" fill={paint('core')} stroke={paint('metal')} strokeWidth="2" strokeLinejoin="round"/>
        <path d="m6 22-1 17 13 13m40-30 1 17-13 13" stroke={paint('edge')} strokeWidth="2"/>
        <path d="m32 9 17 13-3 17-14 16-14-16-3-17Z" fill="#071d52" stroke="#a9d8ff" strokeWidth=".8" strokeLinejoin="round"/>
        <path d="m32 9-17 13 11 4 6-9Z" fill="#a4dfff"/>
        <path d="m32 9 17 13-11 4-6-9Z" fill="#4ba4ff"/>
        <path d="m15 22 3 17 14 16-6-29Z" fill="#245bc8"/>
        <path d="m49 22-3 17-14 16 6-29Z" fill="#092a7b"/>
        <path d="m32 17 6 9-2 12-4 9-4-9-2-12Z" fill={paint('gem')}/>
        <path d="m26 26 6 5 6-5-6-9Z" fill="#6fc1ff"/>
        <path d="m26 26 6 5v16l-4-9Z" fill="#318dff"/>
        <path d="m38 26-6 5v16l4-9Z" fill="#124ac0"/>
        <path d="m18 39 10-1 4 17Z" fill="#185bbd"/>
        <path d="m46 39-10-1-4 17Z" fill="#081d61"/>
        <path d="m32 9-17 13 3 17M15 22l11 4 6-9M26 26l6 5 6-5M32 47v8" stroke="#d1ebff" strokeWidth=".8" strokeLinecap="round" opacity=".85"/>
      </>}
      {emblemKey === 'elite' && <>
        <path d="M32 3 54 14v25L32 61 10 39V14Z" fill="#0a0d14" stroke={paint('metal')} strokeWidth="3" strokeLinejoin="miter"/>
        <path d="m32 9 16 10v17L32 53 16 36V19Z" fill="#131219" stroke="#c78b42" strokeWidth="1"/>
        <path d="m5 17 7 9v13l10 13-12-6-5-16Zm54 0-7 9v13L42 52l12-6 5-16Z" fill={paint('metal')}/>
        <path d="m17 22 9 6 6-15 6 15 9-6-5 20H22Z" fill={paint('gold')} stroke="#fff0b9" strokeWidth=".8" strokeLinejoin="miter"/>
        <path d="m32 13-6 15 6 10Z" fill="#ffe5a1"/>
        <path d="m32 13 6 15-6 10Z" fill="#d38b2b"/>
        <path d="m17 22 9 6 6 10-10 4Z" fill="#f4bd60"/>
        <path d="m47 22-9 6-6 10 10 4Z" fill="#a56121"/>
        <path d="m22 38 10 2 10-2v5H22Z" fill="#ffdc8b"/>
        <path d="m24 43 8 3 8-3-8 9Z" fill={paint('metal')}/>
        <path d="m32 29 4 7-4 5-4-5Z" fill="#4c2913" stroke="#ffedbc" strokeWidth=".6"/>
        <path d="m32 31-2 5 2 2 2-2Z" fill="#fff1bf"/>
        <path d="m17 15 15-8 15 8M18 43l14 14 14-14" stroke="#ffe0a1" strokeWidth=".7" opacity=".7"/>
      </>}
      {emblemKey === 'legendary' && <>
        <path className="rank-ghost" d="M32 4 48 16 59 15 54 42 32 60 10 42 5 15l11 1z"/>
        <path className="rank-stroke" d="M32 4 48 16 59 15 54 42 32 60 10 42 5 15l11 1z"/>
        <path className="rank-thin" d="M32 11 45 21l8-1-4 19-17 14-17-14-4-19 8 1z"/>
      </>}
      {emblemKey === 'master' && <>
        <path d="M32 2 43 13l17-3-7 21 6 17-27 14L5 48l6-17-7-21 17 3Z" fill={paint('core')} stroke={paint('metal')} strokeWidth="2.5" strokeLinejoin="miter"/>
        <path d="m10 17 12 3 10-11 10 11 12-3-6 15 5 12-21 11-21-11 5-12Z" fill="#080c13" stroke={paint('edge')} strokeWidth="1"/>
        <path d="m5 10 6 21-6 17 12-6-3-11 5-12Z" fill={paint('metal')}/>
        <path d="m59 10-6 21 6 17-12-6 3-11-5-12Z" fill={paint('metal')}/>
        <path d="m9 17 6 5-3 10 3 9-6 3 5-13Z" fill="#4b5667"/>
        <path d="m55 17-6 5 3 10-3 9 6 3-5-13Z" fill="#4b5667"/>
        <path d="M32 10 39 20 36 39H28l-3-19Z" fill={paint('gold')} stroke="#fff0b1" strokeWidth=".8" strokeLinejoin="miter"/>
        <path d="m32 10-7 10 3 19h4Z" fill="#fff0b6"/>
        <path d="m32 10 7 10-3 19h-4Z" fill="#c38a2e"/>
        <path d="m32 17-3 6 3 14 3-14Z" fill="#f5c964"/>
        <path d="m20 35 8 4h8l8-4 2 7-10 3h-8l-10-3Z" fill={paint('gold')} stroke="#ffe5a0" strokeWidth=".7" strokeLinejoin="miter"/>
        <path d="m20 35 8 4h8l8-4-2 6H22Z" fill="#ffe49a"/>
        <path d="M29 44h6v8h-6Z" fill="#8c5422" stroke="#e9b85e" strokeWidth=".7"/>
        <path d="m29 46 6 2m-6 0 6 2" stroke="#f6d27a" strokeWidth="1"/>
        <path d="m32 51 4 3-4 3-4-3Z" fill={paint('gold')} stroke="#ffdf94" strokeWidth=".6"/>
        <path d="m20 50 12 7 12-7" stroke={paint('metal')} strokeWidth="2"/>
      </>}
      {/* Broad facets preserve the approved silhouettes at small ranking sizes. */}
      {emblemKey==='diamond'&&<><defs><linearGradient id={id+'-diamond-metal'} x1="6" y1="9" x2="54" y2="57" gradientUnits="userSpaceOnUse"><stop stopColor="#fff1ff"/><stop offset=".25" stopColor="#c3a0f5"/><stop offset=".5" stopColor="#5c337f"/><stop offset=".75" stopColor="#b583ee"/><stop offset="1" stopColor="#42235f"/></linearGradient></defs><path d="M18 7h28l15 19-29 34L3 26Z" fill="#160e25" stroke={paint('diamond-metal')} strokeWidth="2" strokeLinejoin="round"/><path d="M19 11h26l11 15-24 29L8 26Z" fill="#8b48d1"/><path d="m19 11-11 15 15-2 3-9Z" fill="#c99cff"/><path d="m19 11 7 4h12l7-4Z" fill="#f1dfff"/><path d="m45 11-7 4 3 9 15 2Z" fill="#8a4fc7"/><path d="m26 15-3 9h18l-3-9Z" fill="#bd81f1"/><path d="m8 26 15-2 9 31Z" fill="#6a2eac"/><path d="m56 26-15-2-9 31Z" fill="#351159"/><path d="m23 24 9 3v28Z" fill="#bc80fb"/><path d="m41 24-9 3v28Z" fill="#7b3cbd"/><path d="m8 26 15-2 9-9 9 9 15 2M23 24l9 31 9-31" stroke="#e4c3ff" strokeWidth=".7" strokeLinejoin="round"/><path d="m19 11-11 15 8-1" stroke="#fff1ff" strokeWidth="1.1" strokeLinecap="round"/></>}
      {emblemKey==='legendary'&&<>
        <defs><linearGradient id={id+'-inferno'} x1="30" y1="13" x2="34" y2="53" gradientUnits="userSpaceOnUse"><stop stopColor="#ffce8a"/><stop offset=".25" stopColor="#ff702e"/><stop offset=".65" stopColor="#f02b31"/><stop offset="1" stopColor="#8b1229"/></linearGradient></defs>
        <path d="M33 12c5 10-4 13-1 20 4-3 6-8 7-13 6 7 2 12 6 17 5 8-2 15-13 18-11-3-18-10-13-18 3-4 4-8 3-12 7 3 4 10 8 13-5-10-2-15 3-25Z" fill={paint('inferno')} stroke="#ff8d63" strokeWidth=".6" strokeLinejoin="round"/>
        <path d="m33 12-4 18 3 7-9-7 3 12 6 9-11-10 1-7-3 2c-5 8 2 15 13 18 11-3 18-10 13-18l-5-7 1 12-9 10 5-15-5 5-2-11Z" fill="#be142e" opacity=".85"/>
        <path d="M32 29c5 7-2 11 3 14 2-2 3-4 3-7 5 9 0 14-6 16-6-3-10-8-6-14 0 4 2 6 4 7-2-6-1-10 2-16Z" fill="#ff9b32"/>

        <path d="M32 40c3 5-1 6 2 8l-2 3-3-4Z" fill="#fff2ad"/>
      </>}
    </svg>
  </span>;
}
