import { useId } from 'react';

const palettes = [
  { dark: '#255b3d', main: '#68b985', light: '#c7efd0' },
  { dark: '#156d51', main: '#2ed098', light: '#baffdf' },
  { dark: '#0d6874', main: '#24bfca', light: '#c6f8f5' },
  { dark: '#24528a', main: '#61aff4', light: '#d9efff' },
  { dark: '#80551d', main: '#e7b348', light: '#fff0b5' },
] as const;

export default function GreenMedalEmblem({ level }: { level: number }) {
  const id = useId().replace(/:/g, '');
  const palette = palettes[Math.max(0, Math.min(4, level - 1))];
  return <svg className="green-medal-emblem" viewBox="0 0 80 88" fill="none" aria-hidden="true">
    <defs><linearGradient id={`green-medal-${id}`} x1="0" y1="0" x2="1" y2="1">
      <stop stopColor={palette.light}/><stop offset=".46" stopColor={palette.main}/><stop offset="1" stopColor={palette.dark}/>
    </linearGradient></defs>
    <path d="M19 5h18l12 33-15 13L9 16z" fill={palette.dark} stroke={palette.light} strokeWidth="2" strokeLinejoin="round"/>
    <path d="M43 5h18l10 11-25 35-15-13z" fill={palette.main} stroke={palette.light} strokeWidth="2" strokeLinejoin="round"/>
    <path d="M24 12h8l10 28-7 6zM48 12h8L45 46l-7-6z" fill={palette.light} opacity=".32"/>
    <circle cx="40" cy="56" r="27" fill={`url(#green-medal-${id})`} stroke={palette.light} strokeWidth="2.5"/>
    <circle cx="40" cy="56" r="20" fill={palette.dark} stroke={palette.light} strokeWidth="1.8"/>
    <path d="m29 55 7 7 15-16" stroke={palette.light} strokeWidth="5" strokeLinecap="round" strokeLinejoin="round"/>
    {Array.from({ length: 5 }, (_, index) => <circle key={index} cx={28 + index * 6} cy="72" r="1.6" fill={index < level ? palette.light : '#ffffff55'}/>)}
  </svg>;
}
