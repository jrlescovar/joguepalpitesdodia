import { useId } from 'react';

export default function ChestIcon({ size = 64, className, opening = false, halloween = false, graffiti = false }: { size?: number; className?: string; opening?: boolean; halloween?: boolean; graffiti?: boolean }) {
  const id = useId().replace(/:/g, '');
  const gold = `chest-gold-${id}`;
  const wood = `chest-wood-${id}`;
  if(halloween)return <svg className={className} width={size} height={size*(opening?96:72)/80} viewBox={opening?'0 -24 80 96':'0 0 80 72'} fill="none" aria-hidden="true">
    <defs><linearGradient id={gold} x1="14" y1="10" x2="66" y2="65" gradientUnits="userSpaceOnUse"><stop stopColor="#ffda5b"/><stop offset=".4" stopColor="#ff931f"/><stop offset="1" stopColor="#cc460b"/></linearGradient><linearGradient id={wood} x1="40" y1="34" x2="40" y2="62" gradientUnits="userSpaceOnUse"><stop stopColor="#fff887"/><stop offset="1" stopColor="#ffb000"/></linearGradient></defs>
    <path d="M11 33h58v20c0 10-9 14-16 13H27c-8 1-16-3-16-13V33Z" fill={`url(#${gold})`} stroke="#ffc263" strokeWidth="2"/>
    <path d="M25 34c-3 13-3 23 2 31m28-31c3 13 3 23-2 31M40 35v30" stroke="#a8440d" strokeWidth="2" opacity=".45"/>
    <path d="m20 44 8 5 4-4 7 6 7-6 5 4 10-5-4 12-7 4-8-3-8 3-8-5Z" fill="#391707" stroke="#ffde53" strokeWidth="1.3"/>
    <path d="m29 49 4 5 3-5m10 1 3 5 3-5" fill={`url(#${wood})`}/>
    <g className="chest-lid">
      <path d="m36 10 1-8 7-1-2 10" fill="#658837" stroke="#acc05b" strokeWidth="2"/>
      <path d="M10 33V25C10 14 18 7 28 9c8-4 16-4 24 0 11-2 18 6 18 16v8H10Z" fill={`url(#${gold})`} stroke="#ffc263" strokeWidth="2"/>
      <path d="M28 10c-5 6-6 14-5 22m29-22c5 6 6 14 5 22M40 9v22" stroke="#b34b10" strokeWidth="2" opacity=".45"/>
      <path d="m19 18 14 10-15 1Zm42 0-14 10 15 1Z" fill="#351606" stroke="#fff07b" strokeWidth="1.4"/>
      <path d="m40 24-4 6h8Z" fill="#351606"/>
      <path d="M10 33h60" stroke="#ffd478" strokeWidth="3"/>
    </g>
  </svg>;
  return <svg className={className} width={size} height={size * (opening ? 96 : 72) / 80} viewBox={opening ? '0 -24 80 96' : '0 0 80 72'} fill="none" aria-hidden="true">
    <defs>
      <pattern id={`chest-paint-${id}`} width="48" height="44" patternUnits="userSpaceOnUse" patternTransform="rotate(-12)">
        <rect width="48" height="44" fill="#e4ddc6"/>
        <g stroke="#152727" strokeWidth="1.1" strokeLinejoin="round" strokeLinecap="round">
          <path d="M-4 4 6-3l7 5-2 10-7 4-9-4Z" fill="#ed6655"/>
          <path d="m8 2 4 6-6-1 1 5-5-5" fill="none"/>
          <path d="M17-3c-9 5-6 14 1 13l-4 6 6 2 6-9-5-3 6-3Z" fill="#63b9cc"/>
          <path d="m18 1 3 2-4 3m2 6-1 2" fill="none" stroke="#eef2da"/>
          <path d="m31-3 6 8 10-5 4 11-7 7-12-4-6-8Z" fill="#7ab78c"/>
          <path d="m34 3 2 7m5-6 2 5m-8 4 7-1" fill="none"/>
          <path d="M-5 22c4-10 13-10 17-3l-5 4c-5-5-8 1-3 2 15 0 12 17 0 17-5 0-9-3-10-6l6-4c1 6 10 4 7 1-2-2-15 0-12-11Z" fill="#f3b65e"/>
          <path d="M18 23 17 17l6 4 4-5 3 7 6-1-2 6 4 4-8 1-3 8-5-6-7 2 2-8-4-4Z" fill="#dc675f"/>
          <path d="m22 25 1 7m5-8-2 6m-3 3 4 1" fill="none" stroke="#f7d5a0"/>
          <path d="M39 21c9-3 14 7 8 12l2 10-11-3-3-8Z" fill="#c5d9ce"/>
          <ellipse cx="40" cy="29" rx="2" ry="3" fill="#fff8df"/><ellipse cx="46" cy="28" rx="2" ry="3" fill="#fff8df"/>
          <path d="m40 29 0 1m6-3v1m-7 8 6-1-2 3Z" fill="#152727"/>
          <path d="m11 39 2 4m17-3 5 2M5 15l-2 2m29 0 2 3" fill="none"/>
        </g>
        <g fill="#fff7dc"><circle cx="12" cy="14" r=".8"/><circle cx="30" cy="36" r=".7"/><path d="m36 19 1-3 1 3 3 1-3 1-1 3-1-3-3-1Z"/></g>
      </pattern>
      <linearGradient id={gold} x1="9" y1="7" x2="68" y2="66" gradientUnits="userSpaceOnUse"><stop stopColor={graffiti?'#ffffff':'#ffe8a0'}/><stop offset=".47" stopColor={graffiti?'#d3dcd9':'#e5a836'}/><stop offset="1" stopColor={graffiti?'#788d89':'#a65f1f'}/></linearGradient>
      <linearGradient id={wood} x1="16" y1="18" x2="65" y2="62" gradientUnits="userSpaceOnUse"><stop stopColor="#526b84"/><stop offset=".48" stopColor="#30445f"/><stop offset="1" stopColor="#1b2b43"/></linearGradient>
    </defs>
    <path d="M8 32h64v26l-5 9H13l-5-9V32Z" fill="#17253a" stroke={graffiti?'#425451':'#80501f'} strokeWidth="3" strokeLinejoin="round"/>
    <path d="M12 35h56v21l-4 7H16l-4-7V35Z" fill={`url(#${graffiti?`chest-paint-${id}`:wood})`} stroke={`url(#${gold})`} strokeWidth="3" strokeLinejoin="round"/>
    <path d="M13 54h54M25 36v26m30-26v26" stroke={graffiti?'#718780':'#b77726'} strokeWidth="2.7"/>
    <path d="M24 38v17m32-17v17" stroke={graffiti?'#f5f6e9':'#ffe29a'} strokeWidth="1.5"/>
    <path d="M9 36h9v8H9Zm53 0h9v8h-9ZM11 55h10v8h-8Zm48 0h10l-3 8h-7Z" fill={`url(#${gold})`} stroke={graffiti?'#3c504d':'#754817'} strokeWidth="1.6" strokeLinejoin="round"/>
    <path d="M20 65h11v4H18Zm29 0h11l2 4H49Z" fill={graffiti?'#607770':'#9e6125'}/>
    <g className="chest-lid">
      <path d="M8 34V23C8 11 20 5 40 5s32 6 32 18v11H8Z" fill="#15253b" stroke={graffiti?'#425451':'#80501f'} strokeWidth="3"/>
      <path d="M12 31v-8C12 13 23 9 40 9s28 4 28 14v8H12Z" fill={`url(#${graffiti?`chest-paint-${id}`:wood})`} stroke={`url(#${gold})`} strokeWidth="3"/>
      <path d="M23 12c-2 6-3 13-3 20m37-20c2 6 3 13 3 20" stroke={graffiti?'#718780':'#a56822'} strokeWidth="5"/>
      <path d="M24 12c-2 6-3 13-3 20m35-20c2 6 3 13 3 20" stroke={graffiti?'#f1f4ea':'#f9d580'} strokeWidth="1.7"/>
      <path d="M9 31h62v6H9Z" fill={`url(#${gold})`} stroke={graffiti?'#3c504d':'#754817'} strokeWidth="1.5"/>
      <path d="M34 32h12v14l-6 4-6-4V32Z" fill={`url(#${gold})`} stroke={graffiti?'#3c504d':'#754817'} strokeWidth="2" strokeLinejoin="round"/>
      <path d="M37 38c0-3 6-3 6 0 0 2-3 2-3 4" stroke={graffiti?'#253d38':'#3e2a1d'} strokeWidth="2" strokeLinecap="round"/><circle cx="40" cy="45" r="1.1" fill={graffiti?'#253d38':'#3e2a1d'}/>
      <path d="M16 21h5v5h-5Zm43 0h5v5h-5Z" fill={graffiti?'#dce5dc':'#e7b454'} stroke={graffiti?'#536a61':'#85501e'} strokeWidth="1"/>
    </g>
  </svg>;
}
