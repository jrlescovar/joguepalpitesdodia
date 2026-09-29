import { usernameFonts, type UsernameFont } from './usernameFonts';

const cacheKey='username-fonts-used-v1';
const requested=new Set<UsernameFont>();
export function warmUsernameFont(font:UsernameFont) {
  if(font==='normal'||requested.has(font))return;
  const entry=usernameFonts.find(([id])=>id===font);
  if(!entry)return;
  requested.add(font);
  const link=document.createElement('link');
  link.rel='preload';link.as='font';link.type='font/woff2';link.crossOrigin='anonymous';
  link.href='/fonts/'+font+'.woff2?v='+(font==='eater'||font==='butcherman'?'1':'2');
  document.head.appendChild(link);
  try {
    const previous=JSON.parse(localStorage.getItem(cacheKey)||'[]');
    const recent=Array.isArray(previous)?previous.filter(id=>id!==font&&usernameFonts.some(([key])=>key===id)):[];
    localStorage.setItem(cacheKey,JSON.stringify([font,...recent].slice(0,8)));
  }catch{/* Storage can be disabled; font loading still works. */}
}
export function warmRecentUsernameFonts() {
  try {
    const recent=JSON.parse(localStorage.getItem(cacheKey)||'[]');
    if(Array.isArray(recent))for(const font of recent.slice(0,8))warmUsernameFont(font);
  }catch{/* Use normal on-demand loading on a first visit. */}
}
