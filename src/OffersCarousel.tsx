import BoxOffers from './BoxOffers';
import CarouselControls from './CarouselControls';
import { useCardCarousel } from './useCardCarousel';
import { boxCarouselPageStart } from './boxCarouselPages';
import type { Profile } from './types';
import './boxCarousel.css';

const themes=['halloween','classic','font'] as const;
const labels={classic:'ofertas de Personalização',font:'ofertas de Fontes',halloween:'ofertas de Halloween'};
export default function OffersCarousel({profile}:{profile:Profile}){
  const {rail,slides,active,shown,snapStarts,perPage,pageCount,goTo,gestureHandlers}=useCardCarousel(themes);
  const pageLabels=Array.from({length:pageCount},(_,page)=>{
    const start=boxCarouselPageStart(themes.length,page,perPage);
    return themes.slice(start,start+perPage).map(theme=>labels[theme]).join(' e ');
  });
  return <section className="box-carousel offers-carousel" aria-label="Ofertas da loja; deslize para os lados" aria-roledescription="carrossel">
    <h2 className="box-carousel-title">Ofertas da loja</h2>
    <div className="box-carousel-rail" ref={rail} {...gestureHandlers}>
      {themes.map(theme=><div key={theme} className="box-carousel-slide" data-page-start={snapStarts.has(theme)} inert={!shown.includes(theme)} ref={element=>{if(element)slides.current[theme]=element;else delete slides.current[theme];}} role="group" aria-roledescription="slide" aria-label={labels[theme]}><BoxOffers profile={profile} theme={theme}/></div>)}
    </div>
    <CarouselControls active={active} labels={pageLabels} onSelect={goTo} previousLabel="Ofertas anteriores" nextLabel="Próximas ofertas"/>
  </section>;
}
