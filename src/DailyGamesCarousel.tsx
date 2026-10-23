import { useLayoutEffect, useRef, type ReactNode } from 'react';
import CarouselControls from './CarouselControls';
import { useCardCarousel } from './useCardCarousel';
import { firstPlayableGameIndex } from './domain';
import { dailyGameLabel } from './dailyGameDisplay';
import type { Prediction } from './types';
import './boxCarousel.css';
import './dailyCarousel.css';

const keyOf=(game:Prediction)=>`${game.dayId}-${game.slot}`;
const labelOf=(game:Prediction)=>`${dailyGameLabel(game)}: ${game.title}`;

export default function DailyGamesCarousel({games,now,desktop,renderGame,onPageChange}:{games:Prediction[];now:number;desktop:boolean;renderGame:(game:Prediction,instanceId:string,countdownActive:boolean)=>ReactNode;onPageChange:()=>void}) {
  const perPage=desktop?2:1;
  const pages=Array.from({length:Math.ceil(games.length/perPage)},(_,page)=>games.slice(page*perPage,(page+1)*perPage));
  const keys=pages.map(page=>keyOf(page[0]));
  const signature=keys.join('|');
  const {rail,slides,active,settled,shown,snapStarts,goTo,gestureHandlers}=useCardCarousel(keys,{perPage:1,settleNavigation:true});
  const moving=useRef(false);
  const heldHeight=useRef(0);
  const cardHeightFloor=useRef(0);
  useLayoutEffect(()=>{cardHeightFloor.current=0;},[signature,desktop]);
  const fitHeight=useRef(()=>{});
  const releaseHeight=useRef(()=>{});
  function expandForNavigation(){
    const container=rail.current;
    if(desktop||!container)return;
    if(!moving.current)heldHeight.current=container.getBoundingClientRect().height;
    moving.current=true;
    fitHeight.current();
  }
  function navigate(page:number){
    expandForNavigation();
    goTo(page);
    releaseHeight.current();
  }
  useLayoutEffect(()=>{
    const container=rail.current;
    if(!container||desktop)return;
    let touching=false;
    let timer:number|undefined;
    const release=()=>{
      clearTimeout(timer);
      if(touching)return;
      timer=window.setTimeout(()=>{
        moving.current=false;heldHeight.current=0;
        fitHeight.current();
      },200);
    };
    releaseHeight.current=release;
    const scroll=()=>{expandForNavigation();release();};
    const touchStart=()=>{touching=true;clearTimeout(timer);};
    const touchEnd=()=>{touching=false;release();};
    container.addEventListener('scroll',scroll,{passive:true});
    container.addEventListener('touchstart',touchStart,{passive:true});
    container.addEventListener('touchend',touchEnd,{passive:true});
    container.addEventListener('touchcancel',touchEnd,{passive:true});
    return()=>{
      clearTimeout(timer);moving.current=false;heldHeight.current=0;
      releaseHeight.current=()=>{};
      container.removeEventListener('scroll',scroll);
      container.removeEventListener('touchstart',touchStart);
      container.removeEventListener('touchend',touchEnd);
      container.removeEventListener('touchcancel',touchEnd);
    };
  },[signature,desktop]);
  useLayoutEffect(()=>{
    onPageChange();
  },[active,signature,onPageChange]);
  const positioned=useRef('');
  useLayoutEffect(()=>{
    if(positioned.current===signature)return;
    positioned.current=signature;
    goTo(Math.floor(firstPlayableGameIndex(games,now)/perPage),true);
  },[signature]);
  useLayoutEffect(()=>{
    const container=rail.current;
    if(!container)return;
    // Resize only after the gesture settles so layout changes do not interrupt
    // the browser's horizontal momentum and snap animation.
    const target=slides.current[keys[settled]];
    if(!target)return;
    let frame=0;
    const fit=()=>{
      {
        // Match every card to the tallest natural content, including
        // upcoming countdowns. Measure children so the minimum cannot feed back.
        const cards=container.querySelectorAll<HTMLElement>('.daily-card');
        const measured=Array.from(cards,card=>{
          const style=getComputedStyle(card);
          const confirmation=card.querySelector<HTMLElement>('.prediction-content>button');
          const confirmationStyle=confirmation?getComputedStyle(confirmation):null;
          const confirmationHeight=confirmation&&confirmationStyle?confirmation.offsetHeight+parseFloat(confirmationStyle.marginTop)+parseFloat(confirmationStyle.marginBottom):0;
          const height=Array.from(card.children).reduce((height,child)=>height+(desktop?parseFloat(getComputedStyle(child).height):(child as HTMLElement).offsetHeight),0)-confirmationHeight
            +parseFloat(style.borderTopWidth)+parseFloat(style.borderBottomWidth);
          return {card,height};
        });
        const maximum=Math.max(0,...measured.map(entry=>entry.height));
        cardHeightFloor.current=Math.ceil(maximum);
        const minimum=`${cardHeightFloor.current}px`;
        if(container.style.getPropertyValue('--daily-card-height')!==minimum)container.style.setProperty('--daily-card-height',minimum);
        for(const {card,height} of measured){
          const offset=card.querySelector('.daily-header-status')?`${Math.max(0,cardHeightFloor.current-height)}px`:'0px';
          if(card.style.getPropertyValue('--daily-content-offset')!==offset)card.style.setProperty('--daily-content-offset',offset);
        }
      }
      // At rest, fit the selected page. During a mobile swipe, reveal every
      // neighbor at its natural height so taller cards are never clipped.
      const naturalHeight=!desktop&&moving.current
        ? Math.max(heldHeight.current,...Object.values(slides.current).map(slide=>(slide?.offsetHeight??0)+3))
        : target.offsetHeight+3;
      const height=`${naturalHeight}px`;
      if(container.style.height!==height)container.style.height=height;
    };
    fitHeight.current=fit;
    const observer=new ResizeObserver(()=>{
      cancelAnimationFrame(frame);
      frame=requestAnimationFrame(fit);
    });
    Object.values(slides.current).forEach(slide=>{if(slide){observer.observe(slide);slide.querySelectorAll('.daily-card>div').forEach(content=>observer.observe(content));}});
    fit();
    return()=>{observer.disconnect();cancelAnimationFrame(frame);fitHeight.current=()=>{};};
  },[signature,settled,desktop]);
  return <div className={`daily-games-carousel ${desktop?'desktop-games-carousel':'mobile-games'}`} role="region" aria-label="Palpites do dia; deslize para os lados" aria-roledescription="carrossel">
    <div className="box-carousel-rail daily-games-rail" ref={rail} {...gestureHandlers}>
      {pages.map((page,index)=>{const key=keys[index],visible=shown.includes(key);return <div key={key} className={`daily-games-page${desktop?' daily-games desktop-games':''}`} data-page-start={snapStarts.has(key)} inert={!visible} aria-hidden={!visible}
        ref={element=>{if(element)slides.current[key]=element;else delete slides.current[key];}} role="group" aria-roledescription="slide" aria-label={page.map(labelOf).join(' e ')}>
        {page.map(game=><div className="daily-slide" key={keyOf(game)}>{renderGame(game,desktop?`desktop-${index}`:'mobile',visible)}</div>)}
      </div>;})}
    </div>
    <CarouselControls compactSelect={false} active={active} labels={pages.map(page=>page.map(labelOf).join(' e '))} onSelect={navigate} previousLabel="Palpites anteriores" nextLabel="Próximos palpites"/>
  </div>;
}
