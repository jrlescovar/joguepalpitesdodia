import { useCallback, useLayoutEffect, useState } from 'react';
import BoxPanel from './BoxPanel';
import { boxLabels } from './boxThemes';
import { boxCarouselPageStart, boxCarouselTargetPage, boxCarouselThemes } from './boxCarouselPages';
import type { BoxTheme, Profile } from './types';
import { useCardCarousel } from './useCardCarousel';
import CarouselControls from './CarouselControls';
import './boxCarousel.css';

export default function BoxCarousel({profile,refreshTick,refreshAfterCheckout,onChanged,navigateTo,onNavigated}:{profile:Profile;refreshTick:number;refreshAfterCheckout:boolean;onChanged:()=>void;navigateTo:BoxTheme|null;onNavigated:()=>void}){
  const [availability,setAvailability]=useState<Partial<Record<BoxTheme,boolean>>>({});
  const available=boxCarouselThemes.filter(theme=>availability[theme]===true);
  const signature=available.join('|');
  const loading=boxCarouselThemes.some(theme=>availability[theme]===undefined);
  const {rail,slides,active,shown,snapStarts,perPage,pageCount,goTo,gestureHandlers}=useCardCarousel(available);
  const onAvailabilityChange=useCallback((theme:BoxTheme,value:boolean)=>{
    setAvailability(current=>current[theme]===value?current:{...current,[theme]:value});
  },[]);
  useLayoutEffect(()=>{
    if(!navigateTo||availability[navigateTo]!==true)return;
    const page=boxCarouselTargetPage(available,navigateTo,perPage);
    if(page!==null&&!shown.includes(navigateTo))goTo(page,true);
  },[navigateTo,signature,perPage]);
  const pageLabels=Array.from({length:pageCount},(_,page)=>{
    const start=boxCarouselPageStart(available.length,page,perPage);
    return available.slice(start,start+perPage).map(theme=>boxLabels[theme]).join(' e ');
  });
  return <section className="box-carousel" hidden={!loading&&!available.length} aria-label="Minhas caixas; deslize para os lados" aria-roledescription="carrossel">
    <h2 className="box-carousel-title">Minhas caixas</h2>
    {loading&&!available.length&&<p className="muted" role="status">Carregando suas caixas…</p>}
    <div className="box-carousel-rail" ref={rail} {...gestureHandlers}>
      {boxCarouselThemes.map(theme=><div key={theme} className="box-carousel-slide" data-page-start={snapStarts.has(theme)} hidden={availability[theme]!==true} inert={!shown.includes(theme)} ref={element=>{if(element)slides.current[theme]=element;else delete slides.current[theme];}} role="group" aria-roledescription="slide" aria-label={boxLabels[theme]}>
        <BoxPanel profile={profile} theme={theme} refreshTick={refreshTick} refreshAfterCheckout={refreshAfterCheckout&&(theme==='classic'||theme==='font'||theme==='halloween')} onChanged={onChanged} onAvailabilityChange={onAvailabilityChange} navigateTo={navigateTo===theme&&shown.includes(theme)} onNavigated={onNavigated}/>
      </div>)}
    </div>
    <CarouselControls active={active} labels={pageLabels} onSelect={goTo} previousLabel="Caixas anteriores" nextLabel="Próximas caixas"/>
  </section>;
}
