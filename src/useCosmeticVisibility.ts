import {useCallback,useRef} from 'react';
import './cosmeticPerformance.css';

let observer:IntersectionObserver|null=null;
const observed=new Set<HTMLElement>();
const syncVisibility=()=>document.documentElement.toggleAttribute('data-cosmetics-hidden',document.hidden);

function observeCosmetic(node:HTMLElement) {
 if(typeof IntersectionObserver==='undefined')return ()=>{};
 if(!observer){
  observer=new IntersectionObserver(entries=>{
   for(const entry of entries)(entry.target as HTMLElement).toggleAttribute('data-cosmetic-paused',!entry.isIntersecting);
  },{rootMargin:'64px'});
  document.addEventListener('visibilitychange',syncVisibility);
  syncVisibility();
 }
 observed.add(node);observer.observe(node);
 return ()=>{
  observer?.unobserve(node);observed.delete(node);node.removeAttribute('data-cosmetic-paused');
  if(!observed.size){observer?.disconnect();observer=null;document.removeEventListener('visibilitychange',syncVisibility);document.documentElement.removeAttribute('data-cosmetics-hidden');}
 };
}

/** One shared observer, with no scroll handler or layout reads per player. */
export function useCosmeticVisibility<T extends HTMLElement>() {
 const cleanup=useRef<(()=>void)|null>(null);
 return useCallback((node:T|null)=>{
  cleanup.current?.();cleanup.current=node?observeCosmetic(node):null;
 },[]);
}
