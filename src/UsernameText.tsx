import type { UsernameFont } from './usernameFonts';
import { useCallback, useEffect, useLayoutEffect, useRef } from 'react';
import { warmUsernameFont } from './fontLoading';
import { releasedUsernameFonts } from './releasedUsernameFonts';
import {useCosmeticVisibility} from './useCosmeticVisibility';

/** Preserve each layout's base size, with a per-font adjustment for readability. */
export default function UsernameText({name,font='normal',className='',fitToWidth=false}:{name:string;font?:UsernameFont;className?:string;fitToWidth?:boolean}) {
  const textRef=useRef<HTMLSpanElement>(null);
  const cosmeticRef=useCosmeticVisibility<HTMLSpanElement>();
  const setTextRef=useCallback((node:HTMLSpanElement|null)=>{textRef.current=node;cosmeticRef(node);},[cosmeticRef]);
  useEffect(()=>{warmUsernameFont(font);},[font]);
  const extraPixels=releasedUsernameFonts.find(([id])=>id===font)?.[5]??(font==='normal'?0:font==='monocraft'?-2:font==='bebasneue'?2:font==='amaticsc'?6:font==='kalam'?3:font==='quantico'?1:font==='marckscript'?3:font==='metalmania'?2:font==='eater'?-3:0);
  const baseSize=`calc(1em + ${extraPixels}px + var(--username-desktop-increase, 0px) + var(--username-size-increase, 0px))`;
  useLayoutEffect(()=>{
    const text=textRef.current,container=text?.parentElement;
    if(!fitToWidth||!text||!container)return;
    let active=true;
    const mobile=window.matchMedia('(max-width: 640px)');
    const fit=()=>{
      if(!active)return;
      text.style.fontSize=baseSize;
      if(!mobile.matches)return;
      const available=container.clientWidth;
      const natural=text.getBoundingClientRect().width;
      if(available>0&&natural>available){
        const size=parseFloat(getComputedStyle(text).fontSize);
        text.style.fontSize=`${Math.max(1,size*available/natural-.2)}px`;
      }
    };
    const observer=new ResizeObserver(fit);
    observer.observe(container);
    mobile.addEventListener('change',fit);
    document.fonts.addEventListener('loadingdone',fit);
    void document.fonts.ready.then(fit);
    fit();
    return()=>{active=false;observer.disconnect();mobile.removeEventListener('change',fit);document.fonts.removeEventListener('loadingdone',fit);};
  },[name,font,fitToWidth,baseSize]);
  return <span ref={setTextRef} className={'username-text username-font-'+font+' '+className} style={{fontSize:baseSize}}>{name}</span>;
}

