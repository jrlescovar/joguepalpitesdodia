import type { UsernameFont } from './usernameFonts';
import { useEffect } from 'react';
import { warmUsernameFont } from './fontLoading';

/** Preserve each layout's base size, with a per-font adjustment for readability. */
export default function UsernameText({name,font='normal'}:{name:string;font?:UsernameFont}) {
  useEffect(()=>{warmUsernameFont(font);},[font]);
  const extraPixels=font==='normal'?0:font==='monocraft'?-2:font==='bebasneue'?2:font==='amaticsc'?6:font==='dancingscript'?6:font==='kalam'?3:font==='creepster'||font==='quantico'?1:font==='metalmania'||font==='marckscript'||font==='unifrakturcook'?2:font==='eater'?-3:font==='frijole'?-2:0;
  return <span className={'username-font-'+font} style={{fontSize:`calc(1em + ${extraPixels}px + var(--username-desktop-increase, 0px))`}}>{name}</span>;
}

