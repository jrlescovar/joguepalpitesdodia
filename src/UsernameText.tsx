import type { UsernameFont } from './usernameFonts';

/** Add one pixel to the inherited name size without changing each layout's base size. */
export default function UsernameText({name,font='normal'}:{name:string;font?:UsernameFont}) {
  return <span className={'username-font-'+font} style={font==='normal'?undefined:{fontSize:'calc(1em + 1px)'}}>@{name}</span>;
}

