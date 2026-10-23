import {useId} from 'react';

export default function SerieAIcon(){
  const id=useId().replace(/:/g,'');
  return <svg className="serie-a-icon" width="24" height="28" viewBox="140 50 382 445" aria-hidden="true">
    <defs>
      <linearGradient id={`serie-a-${id}`} x1="330" y1="58" x2="330" y2="372" gradientUnits="userSpaceOnUse"><stop stopColor="#22d8ee"/><stop offset="1" stopColor="#0873ff"/></linearGradient>
      <linearGradient id={`serie-a-facet-${id}`} x1="259" y1="372" x2="403" y2="372" gradientUnits="userSpaceOnUse"><stop stopColor="#27def3"/><stop offset=".5" stopColor="#089ef8"/><stop offset="1" stopColor="#0462ef"/></linearGradient>
    </defs>
    <path d="M278 58h104l135 314-186 117-186-117Z" fill={`url(#serie-a-${id})`}/>
    <path d="m330 182-71 190h144l-14-37h-93l26-71h40Z" fill="#1b1857"/>
    <path d="M145 372h114l72 117Z" fill="#1b1857"/>
    <path d="M403 372h114L331 489Z" fill="#1b1857"/>
    <path d="M259 372h144l-72 117Z" fill={`url(#serie-a-facet-${id})`}/>
  </svg>;
}
