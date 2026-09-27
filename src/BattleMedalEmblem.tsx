import { useId } from 'react';

const palettes = [
  { dark: '#64402b', main: '#c78c59', light: '#ffe0b6' },
  { dark: '#455b73', main: '#9cb6d0', light: '#e5f3ff' },
  { dark: '#765016', main: '#e9b842', light: '#fff0b2' },
  { dark: '#533383', main: '#b186ee', light: '#eedaff' },
  { dark: '#1d5575', main: '#64d4ee', light: '#e1fbff' },
] as const;

export default function BattleMedalEmblem({ level }: { level: number }) {
  const id = useId().replace(/:/g, '');
  const palette = palettes[Math.max(0, Math.min(4, level - 1))];
  return <svg className="battle-medal-emblem" viewBox="0 0 80 88" fill="none" aria-hidden="true">
    <defs><linearGradient id={`battle-medal-${id}`} x1="0" y1="0" x2="1" y2="1">
      <stop stopColor={palette.light}/><stop offset=".46" stopColor={palette.main}/><stop offset="1" stopColor={palette.dark}/>
    </linearGradient></defs>
    <path d="M19 5h18l12 33-15 13L9 16z" fill={palette.dark} stroke={palette.light} strokeWidth="2" strokeLinejoin="round"/>
    <path d="M43 5h18l10 11-25 35-15-13z" fill={palette.main} stroke={palette.light} strokeWidth="2" strokeLinejoin="round"/>
    <path d="M24 12h8l10 28-7 6zM48 12h8L45 46l-7-6z" fill={palette.light} opacity=".32"/>
    <path d="m40 28 26 11v18c0 14-14 24-26 29-12-5-26-15-26-29V39z" fill={`url(#battle-medal-${id})`} stroke={palette.light} strokeWidth="2.5" strokeLinejoin="round"/>
    <path d="m40 35 19 8v14c0 10-10 18-19 22-9-4-19-12-19-22V43z" fill={palette.dark} stroke={palette.light} strokeWidth="1.5" strokeLinejoin="round"/>
    <path d="m28 42 6 2 16 19-4 4-17-19zM52 42l-6 2-16 19 4 4 17-19z" fill={palette.light} stroke={palette.main} strokeWidth="1" strokeLinejoin="round"/>
    <path d="m26 61 10 9m8 0 10-9m-24 8-4 4m24-4 4 4" stroke={palette.light} strokeWidth="3" strokeLinecap="round"/>
    {Array.from({ length: 5 }, (_, index) => <circle key={index} cx={28 + index * 6} cy="16" r="1.8" fill={index < level ? palette.light : palette.dark}/>)}
  </svg>;
}
