import { usernameFonts, type UsernameFont } from './usernameFonts';

const cacheKey='username-fonts-used-v1';
const requested=new Set<UsernameFont>();
export function warmUsernameFont(font:UsernameFont) {
  if(font==='normal'||requested.has(font))return;
  const entry=usernameFonts.find(([id])=>id===font);
  if(!entry)return;
  requested.add(font);
  // Load the face actually rendered, without creating unused preload hints.
  const family=entry[2];
  if(family)void document.fonts.load(`16px "${family}"`).catch(()=>{requested.delete(font);});
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
