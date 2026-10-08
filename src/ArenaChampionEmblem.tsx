import {useId} from 'react';
export default function ArenaChampionEmblem(){
 const id=useId().replace(/:/g,'');
 return <svg className="arena-medal-emblem" viewBox="0 0 80 88" fill="none" aria-hidden="true"><defs><linearGradient id={`champ-${id}`} x1="10" y1="10" x2="70" y2="85" gradientUnits="userSpaceOnUse"><stop stopColor="#fff3c0"/><stop offset=".5" stopColor="#eec36a"/><stop offset="1" stopColor="#aa6828"/></linearGradient></defs><path d="M16 4h18l12 27-15 12L8 13zM46 4h18l8 9-24 30-14-12z" fill="#536fb0" stroke="#a3c7ff" strokeWidth="2"/><path d="m40 26 25 14v29L40 84 15 69V40z" fill={`url(#champ-${id})`} stroke="#fff1ba" strokeWidth="2"/><path d="m40 33 19 11v21L40 76 21 65V44z" fill="#3a2d22" stroke="#edc574"/><path d="m25 47 8 6 7-14 7 14 8-6-4 18H29z" fill={`url(#champ-${id})`} stroke="#fff1b8" strokeWidth="1.5" strokeLinejoin="round"/><path d="M30 69h20" stroke="#f7d991" strokeWidth="3" strokeLinecap="round"/></svg>;
}
