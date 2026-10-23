import { ChevronLeft, ChevronRight } from 'lucide-react';

export default function CarouselControls({active,labels,onSelect,previousLabel,nextLabel,compactSelect=true}:{compactSelect?:boolean;active:number;labels:string[];onSelect:(page:number)=>void;previousLabel:string;nextLabel:string}){
  if(labels.length<2)return null;
  return <div className={`box-carousel-controls${compactSelect?' tournament-carousel-controls':''}${compactSelect&&labels.length>5?' many-pages':''}`}>
    <button className="icon-button" type="button" aria-label={previousLabel} disabled={active===0} onClick={()=>onSelect(active-1)}><ChevronLeft size={20}/></button>
    {compactSelect&&labels.length>5&&<select className="carousel-page-select" aria-label="Selecionar página do carrossel" value={active} onChange={event=>onSelect(Number(event.target.value))}>{labels.map((label,page)=><option key={page} value={page}>{page+1} / {labels.length} · {label}</option>)}</select>}
    <div className="box-carousel-dots" aria-label="Selecionar página">{labels.map((label,page)=><button type="button" key={page} className={active===page?'active':''} aria-label={`Mostrar ${label}`} aria-current={active===page?'true':undefined} onClick={()=>onSelect(page)}><span/></button>)}</div>
    <button className="icon-button" type="button" aria-label={nextLabel} disabled={active===labels.length-1} onClick={()=>onSelect(active+1)}><ChevronRight size={20}/></button>
  </div>;
}
