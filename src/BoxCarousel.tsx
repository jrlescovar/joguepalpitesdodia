import LegendaryBox from './LegendaryBox';
import { useCallback, useEffect, useLayoutEffect, useState } from 'react';
import BoxPanel from './BoxPanel';
import { boxLabels } from './boxThemes';
import { boxCarouselPageStart, boxCarouselThemes } from './boxCarouselPages';
import type { BoxTheme, Profile } from './types';
import { useCardCarousel } from './useCardCarousel';
import CarouselControls from './CarouselControls';
import './boxCarousel.css';

export default function BoxCarousel({profile,refreshTick,refreshAfterCheckout,onChanged,navigateTo,onNavigated}:{profile:Profile;refreshTick:number;refreshAfterCheckout:boolean;onChanged:()=>void;navigateTo:BoxTheme|'drops'|'legendary_drops'|null;onNavigated:()=>void}){
  const [legendaryAvailable,setLegendaryAvailable]=useState<boolean|undefined>(undefined);
  const [dropsAvailable,setDropsAvailable]=useState<boolean|undefined>(undefined);
  const [availability,setAvailability]=useState<Partial<Record<BoxTheme,boolean>>>({});
  const available:(BoxTheme|'drops'|'legendary_drops')[]=[...(legendaryAvailable===true?['legendary_drops' as const]:[]),...boxCarouselThemes.filter(theme=>availability[theme]===true)];
  const signature=available.join('|');
  const loading=(legendaryAvailable===undefined)||boxCarouselThemes.some(theme=>availability[theme]===undefined);
  const {rail,slides,active,shown,snapStarts,perPage,pageCount,goTo,gestureHandlers}=useCardCarousel(available);
  const onAvailabilityChange=useCallback((theme:BoxTheme,value:boolean)=>{
    setAvailability(current=>current[theme]===value?current:{...current,[theme]:value});
  },[]);
  useLayoutEffect(()=>{
    if(!navigateTo||!available.includes(navigateTo))return;
    const page=Math.min(Math.floor(available.indexOf(navigateTo)/perPage),pageCount-1);
    if(page!==null&&!shown.includes(navigateTo))goTo(page,true);
  },[navigateTo,signature,perPage]);
  useEffect(()=>{
    if((navigateTo!=='drops'&&navigateTo!=='legendary_drops')||!shown.includes(navigateTo))return;
    const frame=requestAnimationFrame(()=>{
      const panel=slides.current[navigateTo];
      if(!panel||panel.hidden)return;
      panel.closest('.box-carousel')?.scrollIntoView({block:'start',behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});
      panel.querySelector<HTMLButtonElement>('.box-panel-actions .primary-button')?.focus({preventScroll:true});
      onNavigated();
    });
    return()=>cancelAnimationFrame(frame);
  },[navigateTo,signature,active,onNavigated]);
  const pageLabels=Array.from({length:pageCount},(_,page)=>{
    const start=boxCarouselPageStart(available.length,page,perPage);
    return available.slice(start,start+perPage).map(theme=>(theme==='legendary_drops'?'Caixas lendárias':theme==='drops'?'Drops':boxLabels[theme])).join(' e ');
  });
  return <section className="box-carousel" hidden={!loading&&!available.length} aria-label="Minhas caixas; deslize para os lados" aria-roledescription="carrossel">
    <h2 className="box-carousel-title">Minhas caixas</h2>
    {loading&&!available.length&&<p className="muted" role="status">Carregando suas caixas…</p>}
    <div className="box-carousel-rail" ref={rail} {...gestureHandlers}>
      <div className="box-carousel-slide" hidden={legendaryAvailable!==true} data-page-start={snapStarts.has('legendary_drops')} inert={!shown.includes('legendary_drops')} ref={element=>{if(element)slides.current.legendary_drops=element;else delete slides.current.legendary_drops;}} role="group" aria-roledescription="slide" aria-label="Caixas lendárias"><LegendaryBox refreshTick={refreshTick} profile={profile} onChanged={onChanged} onAvailabilityChange={setLegendaryAvailable}/></div>
      {boxCarouselThemes.map(theme=><div key={theme} className="box-carousel-slide" data-page-start={snapStarts.has(theme)} hidden={availability[theme]!==true} inert={!shown.includes(theme)} ref={element=>{if(element)slides.current[theme]=element;else delete slides.current[theme];}} role="group" aria-roledescription="slide" aria-label={boxLabels[theme]}>
        <BoxPanel profile={profile} theme={theme} refreshTick={refreshTick} refreshAfterCheckout={refreshAfterCheckout&&(theme==='classic'||theme==='font'||theme==='halloween')} onChanged={onChanged} onAvailabilityChange={onAvailabilityChange} navigateTo={navigateTo===theme&&shown.includes(theme)} onNavigated={onNavigated}/>
      </div>)}
    </div>
    <CarouselControls active={active} labels={pageLabels} onSelect={goTo} previousLabel="Caixas anteriores" nextLabel="Próximas caixas"/>
  </section>;
}

