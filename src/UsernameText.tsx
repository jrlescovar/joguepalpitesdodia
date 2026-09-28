import type { UsernameFont } from './usernameFonts';

/** Preserve each layout's base size, with a per-font adjustment for readability. */
export default function UsernameText({name,font='normal'}:{name:string;font?:UsernameFont}) {
  const extraPixels=font==='normal'?0:font==='monocraft'?-3:font==='bebasneue'?2:font==='amaticsc'?5:font==='dancingscript'?4:3;
  return <span className={'username-font-'+font} style={extraPixels?{fontSize:`calc(1em + ${extraPixels}px)`}:undefined}>@{name}</span>;
}

