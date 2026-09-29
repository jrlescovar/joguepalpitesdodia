import { useId } from 'react';

export default function ChestIcon({ size = 64, className, opening = false, halloween = false }: { size?: number; className?: string; opening?: boolean; halloween?: boolean }) {
  const id = useId().replace(/:/g, '');
  const gold = `chest-gold-${id}`;
  const wood = `chest-wood-${id}`;
  return <svg className={className} width={size} height={size * (opening ? 96 : 72) / 80} viewBox={opening ? '0 -24 80 96' : '0 0 80 72'} fill="none" aria-hidden="true">
    <defs>
      <linearGradient id={gold} x1="8" y1="12" x2="67" y2="64" gradientUnits="userSpaceOnUse"><stop stopColor={halloween?'#ffd08d':'#ffedb3'}/><stop offset=".5" stopColor={halloween?'#f78435':'#eeb95e'}/><stop offset="1" stopColor={halloween?'#9f3d55':'#a86f28'}/></linearGradient>
      <linearGradient id={wood} x1="40" y1="22" x2="40" y2="64" gradientUnits="userSpaceOnUse"><stop stopColor={halloween?'#492742':'#815625'}/><stop offset="1" stopColor={halloween?'#171323':'#3f2c1c'}/></linearGradient>
    </defs>
    <path d="M12 34h56v25a5 5 0 0 1-5 5H17a5 5 0 0 1-5-5V34Z" fill={`url(#${wood})`} stroke={`url(#${gold})`} strokeWidth="3"/>
    <path d="M22 34v29m36-29v29" stroke="#edc478" strokeWidth="4"/>
    <g className="chest-lid">
      <path d="M10 33V25c0-12 9-18 17-18h26c9 0 17 7 17 18v8H10Z" fill={`url(#${wood})`} stroke={`url(#${gold})`} strokeWidth="3"/>
      <path d="M22 9v24m36-24v24" stroke="#edc478" strokeWidth="4"/>
      <path d="M10 33h60" stroke="#ffe0a0" strokeWidth="4"/>
      <rect x="32" y="28" width="16" height="20" rx="3" fill="#e6b45d" stroke="#ffe5aa" strokeWidth="2"/>
      {halloween?<text x="40" y="43" textAnchor="middle" fill="#3d1c2c" fontSize="15" fontWeight="900">?</text>:<><path d="M37 35.5c0-4 6-4 6 0 0 2.5-3 2.5-3 5" stroke="#3d2c1b" strokeWidth="2.2" strokeLinecap="round"/><circle cx="40" cy="44" r="1.2" fill="#3d2c1b"/></>}
      <path d="M27 16h25" stroke="#fff0bd" strokeWidth="2" strokeLinecap="round" opacity=".65"/>
    </g>
    <path d="m69 4 1.8 4.8L76 11l-5.2 2-1.8 5-2-5-5-2 5-2.2L69 4Z" fill="#ffe7a8"/>
  </svg>;
}
