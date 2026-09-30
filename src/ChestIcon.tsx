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
  if(graffiti)return <svg className={className} width={size} height={size*(opening?96:72)/80} viewBox={opening?'0 -24 80 96':'0 0 80 72'} fill="none" aria-hidden="true">
    <defs>
      <linearGradient id={gold} x1="10" y1="8" x2="68" y2="66" gradientUnits="userSpaceOnUse"><stop stopColor="#ffffff"/><stop offset=".45" stopColor="#dce1eb"/><stop offset="1" stopColor="#7b849e"/></linearGradient>
      <linearGradient id={wood} x1="14" y1="12" x2="66" y2="61" gradientUnits="userSpaceOnUse"><stop stopColor="#272334"/><stop offset="1" stopColor="#101019"/></linearGradient>
      <clipPath id={`street-body-${id}`}><path d="M12 35h56v21l-4 7H16l-4-7V35Z"/></clipPath>
      <clipPath id={`street-lid-${id}`}><path d="M12 31v-8C12 13 23 9 40 9s28 4 28 14v8H12Z"/></clipPath>
    </defs>
    <path d="M8 32h64v26l-5 9H13l-5-9V32Z" fill="#101019" stroke="#080910" strokeWidth="3" strokeLinejoin="round"/>
    <path d="M12 35h56v21l-4 7H16l-4-7V35Z" fill={`url(#${wood})`} stroke={`url(#${gold})`} strokeWidth="3" strokeLinejoin="round"/>
    <g clipPath={`url(#street-body-${id})`}>
      <path d="m7 40 17-9 8 9-11 8 14 8-10 13H6Z" fill="#ff327c"/>
      <path d="m47 31 8 14 17-10 7 16-20 16-12-6 9-11-15-6Z" fill="#26dce8"/>
      <path d="m11 56 18-13-8 13 11-3-13 13" fill="#ffe743" stroke="#11121d" strokeWidth="1.6" strokeLinejoin="round"/>
      <path d="m58 39 3 7 8-3-5 7 5 3-8 1-4 9-2-9-7-3 8-4Z" fill="#c8ff45" stroke="#11121d" strokeWidth="1.4"/>
      <path d="M17 40v11m4-13v6m38 9v11m4-13v5" stroke="#ff327c" strokeWidth="2" strokeLinecap="round"/>
      <g stroke="#090b14" strokeWidth="7" strokeLinecap="square" strokeLinejoin="miter"><path d="m27 56 8-11 3 13m-9-6 7-1m6 4c-1-6 9-9 8-2l-1 5m0-6c-8-1-10 9-1 5"/></g>
      <g stroke="#ffffff" strokeWidth="3" strokeLinecap="square" strokeLinejoin="miter"><path d="m27 56 8-11 3 13m-9-6 7-1m6 4c-1-6 9-9 8-2l-1 5m0-6c-8-1-10 9-1 5"/></g>
      <path d="m25 61 26-3" stroke="#ffe743" strokeWidth="1.7" strokeLinecap="round"/>
      <g fill="#fff"><circle cx="17" cy="38" r="1"/><circle cx="62" cy="59" r="1.1"/><circle cx="53" cy="39" r=".7"/><path d="m18 46 1-3 1 3 3 1-3 1-1 3-1-3-3-1Z"/></g>
    </g>
    <path d="M9 36h8v8H9Zm54 0h8v8h-8ZM11 55h9v8h-7Zm49 0h9l-3 8h-6Z" fill={`url(#${gold})`} stroke="#34374b" strokeWidth="1.5" strokeLinejoin="round"/>
    <path d="M20 65h11v4H18Zm29 0h11l2 4H49Z" fill="#50566d"/>
    <g className="chest-lid">
      <path d="M8 34V23C8 11 20 5 40 5s32 6 32 18v11H8Z" fill="#101019" stroke="#080910" strokeWidth="3"/>
      <path d="M12 31v-8C12 13 23 9 40 9s28 4 28 14v8H12Z" fill={`url(#${wood})`} stroke={`url(#${gold})`} strokeWidth="3"/>
      <g clipPath={`url(#street-lid-${id})`}>
        <path d="m6 28 22-21 9 7-16 22Z" fill="#26dce8"/>
        <path d="m33 7 19 4-9 11 24-5 8 16H31l11-10-16 2Z" fill="#ff327c"/>
        <path d="m60 9-7 11 10-2-7 13 18-13Z" fill="#c8ff45" stroke="#11121d" strokeWidth="1.4"/>
        <g transform="rotate(-8 40 22)" strokeLinecap="square" strokeLinejoin="miter">
          <path d="m22 27 2-12h9m-10 6h7m5 6 2-12 5 12 2-12m3 0h9m-5 0-2 12" stroke="#090b14" strokeWidth="7"/>
          <path d="m22 27 2-12h9m-10 6h7m5 6 2-12 5 12 2-12m3 0h9m-5 0-2 12" stroke="#fff" strokeWidth="3"/>
        </g>
        <path d="m32 29 19-2" stroke="#ffe743" strokeWidth="1.6" strokeLinecap="round"/>
        <g fill="#fff"><circle cx="16" cy="23" r=".8"/><circle cx="61" cy="28" r="1"/><circle cx="36" cy="12" r=".7"/></g>
      </g>
      <path d="M9 31h62v6H9Z" fill={`url(#${gold})`} stroke="#34374b" strokeWidth="1.5"/>
      <path d="M34 32h12v11l-6 4-6-4V32Z" fill="#171824" stroke="#e8edf6" strokeWidth="1.8" strokeLinejoin="round"/>
      <path d="m37 36 6 0m-5 3 4 0m-3 0v4" stroke="#ffe743" strokeWidth="1.6" strokeLinecap="round"/>
    </g>
  </svg>;
  return <svg className={className} width={size} height={size * (opening ? 96 : 72) / 80} viewBox={opening ? '0 -24 80 96' : '0 0 80 72'} fill="none" aria-hidden="true">
    <defs>
      <linearGradient id={gold} x1="9" y1="7" x2="68" y2="66" gradientUnits="userSpaceOnUse"><stop stopColor="#ffe8a0"/><stop offset=".47" stopColor="#e5a836"/><stop offset="1" stopColor="#a65f1f"/></linearGradient>
      <linearGradient id={wood} x1="16" y1="18" x2="65" y2="62" gradientUnits="userSpaceOnUse"><stop stopColor="#526b84"/><stop offset=".48" stopColor="#30445f"/><stop offset="1" stopColor="#1b2b43"/></linearGradient>
    </defs>
    <path d="M8 32h64v26l-5 9H13l-5-9V32Z" fill="#17253a" stroke="#80501f" strokeWidth="3" strokeLinejoin="round"/>
    <path d="M12 35h56v21l-4 7H16l-4-7V35Z" fill={`url(#${wood})`} stroke={`url(#${gold})`} strokeWidth="3" strokeLinejoin="round"/>
    <path d="M13 54h54M25 36v26m30-26v26" stroke="#b77726" strokeWidth="2.7"/>
    <path d="M24 38v17m32-17v17" stroke="#ffe29a" strokeWidth="1.5"/>
    <path d="M9 36h9v8H9Zm53 0h9v8h-9ZM11 55h10v8h-8Zm48 0h10l-3 8h-7Z" fill={`url(#${gold})`} stroke="#754817" strokeWidth="1.6" strokeLinejoin="round"/>
    <path d="M20 65h11v4H18Zm29 0h11l2 4H49Z" fill="#9e6125"/>
    <g className="chest-lid">
      <path d="M8 34V23C8 11 20 5 40 5s32 6 32 18v11H8Z" fill="#15253b" stroke="#80501f" strokeWidth="3"/>
      <path d="M12 31v-8C12 13 23 9 40 9s28 4 28 14v8H12Z" fill={`url(#${wood})`} stroke={`url(#${gold})`} strokeWidth="3"/>
      <path d="M23 12c-2 6-3 13-3 20m37-20c2 6 3 13 3 20" stroke="#a56822" strokeWidth="5"/>
      <path d="M24 12c-2 6-3 13-3 20m35-20c2 6 3 13 3 20" stroke="#f9d580" strokeWidth="1.7"/>
      <path d="M9 31h62v6H9Z" fill={`url(#${gold})`} stroke="#754817" strokeWidth="1.5"/>
      <path d="M34 32h12v14l-6 4-6-4V32Z" fill={`url(#${gold})`} stroke="#754817" strokeWidth="2" strokeLinejoin="round"/>
      <path d="M37 38c0-3 6-3 6 0 0 2-3 2-3 4" stroke="#3e2a1d" strokeWidth="2" strokeLinecap="round"/><circle cx="40" cy="45" r="1.1" fill="#3e2a1d"/>
      <path d="M16 21h5v5h-5Zm43 0h5v5h-5Z" fill="#e7b454" stroke="#85501e" strokeWidth="1"/>
    </g>
  </svg>;
}
