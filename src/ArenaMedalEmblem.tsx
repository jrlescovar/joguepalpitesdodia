import {useId} from 'react';
export default function ArenaMedalEmblem(){
 const id=useId().replace(/:/g,'');
 return <svg className="arena-medal-emblem" viewBox="0 0 80 88" fill="none" aria-hidden="true">
  <defs><linearGradient id={`arena-medal-${id}`} x1="0" y1="0" x2="1" y2="1"><stop stopColor="#fff1ba"/><stop offset=".5" stopColor="#e5b95c"/><stop offset="1" stopColor="#97632d"/></linearGradient></defs>
  <path d="M16 5h17l11 27-12 17L7 14z" fill="#8b5929" stroke="#f5d78d" strokeWidth="2" strokeLinejoin="round"/>
  <path d="M46 5h18l9 9-24 35-12-17z" fill="#c68b3e" stroke="#f5d78d" strokeWidth="2" strokeLinejoin="round"/>
  <circle cx="40" cy="57" r="27" fill={`url(#arena-medal-${id})`} stroke="#fff1ba" strokeWidth="2.5"/>
  <circle cx="40" cy="57" r="20" fill="#42301d" stroke="#f8d985" strokeWidth="1.5"/>
  <path d="m26 62-3-17 10 7 7-14 7 14 10-7-3 17H26zm3 5h22" fill="#e8b857" stroke="#fff1ba" strokeWidth="2" strokeLinejoin="round"/>
  <circle cx="40" cy="45" r="2" fill="#fff1ba"/>
 </svg>;
}
