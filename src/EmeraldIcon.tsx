import { useId } from 'react';
export default function EmeraldIcon({size=24,className=''}:{size?:number;className?:string}) {
 const id=useId().replace(/:/g,'');
 return <svg width={size} height={size} viewBox="0 0 80 88" className={`emerald-icon ${className}`} aria-hidden="true" fill="none">
  <defs>
   <linearGradient id={`${id}-body`} x1="22" y1="10" x2="60" y2="76" gradientUnits="userSpaceOnUse">
    <stop stopColor="#79e8c3"/><stop offset=".48" stopColor="#35c99c"/><stop offset="1" stopColor="#16785c"/>
   </linearGradient>
   <linearGradient id={`${id}-face`} x1="27" y1="25" x2="52" y2="68" gradientUnits="userSpaceOnUse">
    <stop stopColor="#71e2ba"/><stop offset="1" stopColor="#219573"/>
   </linearGradient>
  </defs>
  <path d="M26 10h28l15 18v29L40 79 11 57V28Z" fill={`url(#${id}-body)`} stroke="#78ddba" strokeWidth="1.6" strokeLinejoin="round"/>
  <path d="M26 10h28l-8 16H34Z" fill="#a4efd5"/>
  <path d="m26 10 8 16-10 10-13-8Z" fill="#69d9b2"/>
  <path d="m54 10 15 18-13 8-10-10Z" fill="#42bb93"/>
  <path d="m24 36 10-10h12l10 10v17L40 68 24 53Z" fill={`url(#${id}-face)`}/>
  <path d="m11 28 13 8v17L11 57Z" fill="#2cb78d"/>
  <path d="m69 28-13 8v17l13 4Z" fill="#148261"/>
  <path d="m11 57 13-4 16 15v11Z" fill="#19926e"/>
  <path d="m69 57-13-4-16 15v11Z" fill="#12654e"/>
  <path d="M26 10h28M11 28l13 8 10-10" stroke="#c1f7e3" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" opacity=".65"/>
 </svg>;
}
