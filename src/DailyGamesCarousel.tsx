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
  useLayoutEffect(()=>{
    const container=rail.current;
    if(!container)return;
    // Keep the scrolling surface stable while the pending button disappears.
    // Release the extra height once the destination card has snapped in place.
    // Preserve fractional pixels too: rounding up briefly pushes every section
    // below the carousel down, then back up when navigation settles.
    container.style.minHeight=!desktop&&active!==settled?`${container.getBoundingClientRect().height}px`:'';
  },[active,settled,desktop]);
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
    // On mobile the flex rail sizes every card to the tallest content. A fixed
    // height based on the selected card clips taller neighbors during a swipe.
    if(!desktop){container.style.height='';return;}
    // Resize only after the gesture settles so layout changes do not interrupt
    // the browser's horizontal momentum and snap animation.
    const target=slides.current[keys[settled]];
    if(!target)return;
    let frame=0;
    const fit=()=>{
      const height=`${Math.ceil(target.getBoundingClientRect().height)+3}px`;
      if(container.style.height!==height)container.style.height=height;
    };
    const observer=new ResizeObserver(()=>{
      cancelAnimationFrame(frame);
      frame=requestAnimationFrame(fit);
    });
    observer.observe(target);fit();
    return()=>{observer.disconnect();cancelAnimationFrame(frame);};
  },[signature,settled,desktop]);
  return <div className={`daily-games-carousel ${desktop?'desktop-games-carousel':'mobile-games'}`} role="region" aria-label="Palpites do dia; deslize para os lados" aria-roledescription="carrossel">
    <div className="box-carousel-rail daily-games-rail" ref={rail} {...gestureHandlers}>
      {pages.map((page,index)=>{const key=keys[index],visible=shown.includes(key);return <div key={key} className={`daily-games-page${desktop?' daily-games desktop-games':''}`} data-page-start={snapStarts.has(key)} inert={!visible} aria-hidden={!visible}
        ref={element=>{if(element)slides.current[key]=element;else delete slides.current[key];}} role="group" aria-roledescription="slide" aria-label={page.map(labelOf).join(' e ')}>
        {page.map(game=><div className="daily-slide" key={keyOf(game)}>{renderGame(game,desktop?`desktop-${index}`:'mobile',visible)}</div>)}
      </div>;})}
    </div>
    <CarouselControls active={active} labels={pages.map(page=>page.map(labelOf).join(' e '))} onSelect={goTo} previousLabel="Palpites anteriores" nextLabel="Próximos palpites"/>
  </div>;
}
