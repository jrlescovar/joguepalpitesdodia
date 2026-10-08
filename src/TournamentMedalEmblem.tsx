import { useId } from 'react';

export default function TournamentMedalEmblem() {
  const id=useId().replace(/:/g,'');
  return <svg className="tournament-medal-emblem" viewBox="0 0 80 88" fill="none" aria-hidden="true">
    <defs><linearGradient id={`tournament-medal-${id}`} x1="0" y1="0" x2="1" y2="1"><stop stopColor="#fff1ba"/><stop offset=".5" stopColor="#e5b95c"/><stop offset="1" stopColor="#97632d"/></linearGradient></defs>
    <path d="M16 5h17l11 27-12 17L7 14z" fill="#315d98" stroke="#9cc8ff" strokeWidth="2" strokeLinejoin="round"/>
    <path d="M46 5h18l9 9-24 35-12-17z" fill="#619de5" stroke="#b7d9ff" strokeWidth="2" strokeLinejoin="round"/>
    <path d="M12 47c5 5 11 7 17 3l6-7 8 13c3 4 9 6 17 8l8 3c4 2 6 5 5 9H11c-2-10-1-21 1-29Z" fill={`url(#tournament-medal-${id})`} stroke="#ffe9a6" strokeWidth="1.8" strokeLinejoin="round"/>
    <path d="M13 47c6 6 13 8 18 3l4-7 4 6-7 9c-7 3-13 0-20-4" fill="#48331e" stroke="#edc775" strokeWidth="1.3" strokeLinejoin="round"/>
    <path d="m35 52 9 7m-13-2 9 7m-12-1 8 6" stroke="#725028" strokeWidth="2" strokeLinecap="round"/>
    <path d="m39 69 10-9 6 3-9 9m5-1 8-6" stroke="#fff1be" strokeWidth="2.5" strokeLinecap="round"/>
    <path d="M13 61v10m49-4c4 1 7 3 8 6" stroke="#c0913e" strokeWidth="1.5" strokeLinecap="round"/>
    <path d="M11 75h62v4H11z" fill="#a77532" stroke="#f1ca74" strokeWidth="1.3" strokeLinejoin="round"/>
    <path d="M16 79v5h5v-5m9 0v4h5v-4m16 0v4h5v-4m9 0v4h5v-4" fill="#edc775" stroke="#a77532" strokeWidth="1.2" strokeLinejoin="round"/>
  </svg>;
}
