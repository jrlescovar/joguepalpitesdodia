import { useId } from 'react';
import type { ProfileBackgroundStyle } from './types';

/** Compact vector scenes share the same artwork in the profile and inventory. */
export default function HalloweenScene({style}:{style:ProfileBackgroundStyle}) {
  const id=useId().replace(/:/g,'');
  if(style==='none')return null;
  const house=style==='halloween-house';
  const bats=style==='halloween-bats';
  return <svg className={`halloween-scene${bats?' halloween-scene-bats':''}`} viewBox="0 0 600 320" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
    <defs><linearGradient id={`night-${id}`} x2="0" y2="1"><stop stopColor={house?'#462340':'#242d50'}/><stop offset="1" stopColor="#0d1323"/></linearGradient><radialGradient id={`moon-${id}`}><stop stopColor="#ffe1aa"/><stop offset=".78" stopColor="#efb46c"/><stop offset="1" stopColor="#e4a061" stopOpacity="0"/></radialGradient></defs>
    <path fill={`url(#night-${id})`} d="M0 0h600v320H0z"/>
    <circle cx="495" cy="72" r="55" fill={`url(#moon-${id})`}/>
    <g fill="#e8d3b2" opacity=".45"><circle cx="47" cy="35" r="1.5"/><circle cx="180" cy="62" r="1"/><circle cx="335" cy="31" r="1.3"/><circle cx="398" cy="88" r="1"/></g>
    <path d="M0 253q70-44 143-7t142 5 151-22 164 22v69H0z" fill="#111322"/>
    {house?<g stroke="#0c1020" strokeWidth="3" fill="#181329"><path d="M38 247V135l50-48 50 48v112zm78 0V169l39-32 40 32v78zM31 136l58-60 60 60z"/><path d="M64 101V72h13v16"/><path d="M66 165h17v23H66zm30 0h17v23H96zm44 26h17v20h-17z" fill="#ed984b" stroke="none"/><path d="M75 247v-35q13-20 26 0v35" fill="#080e1b"/></g>:<g fill="#191e31" stroke="#292f40" strokeWidth="2"><path d="M40 262v-44q0-22 18-22t18 22v44zm51-4v-30q0-15 14-15t14 15v30zm431 4v-46q0-24 20-24t20 24v46z"/><path d="M51 220h14m-7-8v28m477-22h14m-7-8v28" stroke="#485066"/></g>}
    <g fill="#0b0f1b"><path d="m8 269 7-90-21-27 25 18 11-37-3 60 25-13-23 26-4 66zm562 11-3-93-30-24 28 7-4-38 18 39 23-14-25 36 9 87z"/></g>
    <g className="halloween-flying-bats" fill="#0b1020"><path d="m442 88-21-12 5 17 10-2 6 8 7-8 10 2 5-17zm76 43-16-9 4 14 8-2 4 6 5-6 8 2 4-14z"/>{bats&&<path d="m385 49-29-16 7 24 13-4 9 11 9-11 13 4 7-24zm-268 17-20-12 5 17 10-3 5 8 6-8 10 3 5-17z"/>}</g>
    <path className="halloween-scene-mist" d="M0 283q90-38 170-12t153-2 134 0 143-15v66H0z" fill="#a388bd" opacity=".12"/>
  </svg>;
}
