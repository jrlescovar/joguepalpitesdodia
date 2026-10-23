import { useEffect, useLayoutEffect, useRef, useState, type PointerEvent } from 'react';
import { CarouselIndicator } from './carouselIndicator';
import { boxCarouselPageCount, boxCarouselPageStart } from './boxCarouselPages';

// Shared by purchase offers and owned boxes so selection behaves identically.
export function useCardCarousel<Key extends string>(keys:readonly Key[],options?:{perPage?:number;settleNavigation?:boolean}){
  const [desktop,setDesktop]=useState(()=>window.matchMedia('(min-width: 1200px)').matches);
  const [active,setActive]=useState(0);
  const [settled,setSettled]=useState(0);
  const activeRef=useRef(active);activeRef.current=active;
  const indicator=useRef(new CarouselIndicator());
  const rail=useRef<HTMLDivElement>(null);
  const slides=useRef<Partial<Record<Key,HTMLDivElement>>>({});
  const dragStart=useRef<{x:number;page:number}|null>(null);
  const requested=useRef<number|null>(null);
  const perPage=options?.perPage??(desktop?3:1);
  const pageCount=boxCarouselPageCount(keys.length,perPage);
  const start=boxCarouselPageStart(keys.length,active,perPage);
  const shown=keys.slice(start,start+perPage);
  const snapStarts=new Set(Array.from({length:pageCount},(_,page)=>keys[boxCarouselPageStart(keys.length,page,perPage)]));
  const signature=keys.join('|');

  useEffect(()=>{
    const media=window.matchMedia('(min-width: 1200px)');
    const update=()=>setDesktop(media.matches);
    media.addEventListener('change',update);
    return()=>media.removeEventListener('change',update);
  },[]);

  function pageOffset(page:number){
    const container=rail.current;
    const first=slides.current[keys[0]];
    const target=slides.current[keys[boxCarouselPageStart(keys.length,page,perPage)]];
    if(!container||!first||!target)return 0;
    return Math.max(0,Math.min(target.offsetLeft-first.offsetLeft,container.scrollWidth-container.clientWidth));
  }
  function offsets(){return Array.from({length:pageCount},(_,page)=>pageOffset(page));}
  function goTo(page:number,instant=false){
    const container=rail.current;
    if(!container||!pageCount)return;
    const next=Math.max(0,Math.min(page,pageCount-1));
    if(options?.settleNavigation)requested.current=next;
    indicator.current.select(next);activeRef.current=next;setActive(next);
    const immediate=instant||window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const left=pageOffset(next);
    if(immediate||Math.abs(container.scrollLeft-left)<1)setSettled(next);
    container.scrollTo({left,behavior:immediate?'instant':'smooth'});
  }

  useLayoutEffect(()=>{
    const container=rail.current;
    if(!container||!pageCount)return;
    let frame=0;
    let settleTimer:number|undefined;
    let touching=false;
    const finish=()=>{
      clearTimeout(settleTimer);
      if(touching||!options?.settleNavigation)return;
      // Native momentum may stop short of a snap point, especially when card
      // heights differ. Settle swipes as well as explicit arrow/dot navigation.
      const target=requested.current??indicator.current.read(container.scrollLeft,offsets());
      requested.current=null;indicator.current.cancel();
      const left=pageOffset(target);
      if(Math.abs(container.scrollLeft-left)>0.5)container.scrollTo({left,behavior:'instant'});
      activeRef.current=target;setActive(target);setSettled(target);
    };
    const update=()=>{const next=indicator.current.read(container.scrollLeft,offsets());activeRef.current=next;setActive(next);};
    const schedule=()=>{cancelAnimationFrame(frame);frame=requestAnimationFrame(update);if(options?.settleNavigation){clearTimeout(settleTimer);settleTimer=window.setTimeout(finish,160);}};
    const touchStart=()=>{touching=true;requested.current=null;indicator.current.cancel();clearTimeout(settleTimer);};
    const touchEnd=()=>{touching=false;schedule();};
    const observer=new ResizeObserver(schedule);
    observer.observe(container);
    keys.forEach(key=>{const slide=slides.current[key];if(slide)observer.observe(slide);});
    container.addEventListener('scroll',schedule,{passive:true});
    if(options?.settleNavigation){
      container.addEventListener('scrollend',finish);
      container.addEventListener('touchstart',touchStart,{passive:true});
      container.addEventListener('touchend',touchEnd,{passive:true});
      container.addEventListener('touchcancel',touchEnd,{passive:true});
    }
    goTo(activeRef.current,true);
    return()=>{observer.disconnect();container.removeEventListener('scroll',schedule);container.removeEventListener('scrollend',finish);container.removeEventListener('touchstart',touchStart);container.removeEventListener('touchend',touchEnd);container.removeEventListener('touchcancel',touchEnd);clearTimeout(settleTimer);cancelAnimationFrame(frame);};
  },[signature,perPage,options?.settleNavigation]);

  const gestureHandlers={
    onPointerDown(event:PointerEvent<HTMLDivElement>){
      indicator.current.cancel();dragStart.current=null;requested.current=null;
      if(rail.current){const next=indicator.current.read(rail.current.scrollLeft,offsets());activeRef.current=next;setActive(next);}
      if(event.pointerType==='mouse'&&!(event.target as Element).closest('button,a'))dragStart.current={x:event.clientX,page:activeRef.current};
    },
    onPointerUp(event:PointerEvent<HTMLDivElement>){
      const previous=dragStart.current;dragStart.current=null;
      if(previous&&event.pointerType==='mouse'&&Math.abs(event.clientX-previous.x)>=45)goTo(previous.page+(event.clientX<previous.x?1:-1));
    },
    onPointerCancel(){dragStart.current=null;},
    onWheel(){indicator.current.cancel();requested.current=null;},
  };
  return {rail,slides,active,settled,shown,snapStarts,perPage,pageCount,goTo,gestureHandlers};
}
