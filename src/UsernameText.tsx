import type { UsernameFont } from './usernameFonts';
import { useEffect } from 'react';
import { warmUsernameFont } from './fontLoading';

/** Preserve each layout's base size, with a per-font adjustment for readability. */
export default function UsernameText({name,font='normal'}:{name:string;font?:UsernameFont}) {
  useEffect(()=>{warmUsernameFont(font);},[font]);
  const extraPixels=font==='normal'?0:font==='monocraft'?-2:font==='bebasneue'?2:font==='amaticsc'?6:font==='dancingscript'?6:font==='kalam'?3:font==='creepster'||font==='quantico'?1:font==='metalmania'?2:font==='eater'?-3:font==='frijole'?-2:0;
  return <span className={'username-font-'+font} style={extraPixels?{fontSize:`calc(1em + ${extraPixels}px)`}:undefined}>{name}</span>;
}

