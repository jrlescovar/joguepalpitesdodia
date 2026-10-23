import { forwardRef, useId } from 'react';
import WheelPrizeIcon from './WheelPrizeIcon';
import { wheelSegments } from './wheelGeometry';
import type { WheelPrize } from './types';

const colors:Record<WheelPrize['kind'],string>={classic:'#62481f',halloween:'#783c27',font:'#514077',name:'#23565b',frame:'#2f4c76',legendary:'#a77728',supporter:'#a77728',empty:'#252d3b'};
const point=(angle:number,radius:number)=>{
  const radians=angle*Math.PI/180;
  return [160+radius*Math.sin(radians),160-radius*Math.cos(radians)];
};

export function WheelFace({prizes}:{prizes:WheelPrize[]}){
  const id=useId().replace(/:/g,'');
  const segments=wheelSegments(prizes);
  return <svg className="wheel-face" viewBox="0 0 320 320" fill="none" aria-hidden="true">
    <defs>
      <radialGradient id={`surface-${id}`} cx=".35" cy=".2" r=".9"><stop stopColor="#fff" stopOpacity=".09"/><stop offset=".6" stopColor="#fff" stopOpacity="0"/><stop offset="1" stopColor="#000" stopOpacity=".4"/></radialGradient>
    </defs>
    <circle cx="160" cy="160" r="154" fill="#202735"/>
    {segments.map(prize=>{
      const [x1,y1]=point(prize.start,154),[x2,y2]=point(prize.end,154);
      return <path key={prize.position} d={`M160 160L${x1} ${y1}A154 154 0 ${prize.end-prize.start>180?1:0} 1 ${x2} ${y2}Z`} fill={colors[prize.kind]}/>;
    })}
    <circle cx="160" cy="160" r="154" fill={`url(#surface-${id})`}/>
    {segments.map(prize=>{
      const [x1,y1]=point(prize.start,46),[x2,y2]=point(prize.start,148);
      return <path key={prize.position} d={`M${x1} ${y1}L${x2} ${y2}`} stroke="#edd9ab" strokeOpacity=".2" strokeWidth="1"/>;
    })}
    <circle cx="160" cy="160" r="146" stroke="#f1d7a0" strokeOpacity=".16" strokeWidth="1"/>
  </svg>;
}

export function WheelRim(){
  const id=useId().replace(/:/g,'');
  return <svg className="wheel-rim" viewBox="0 0 320 320" fill="none" aria-hidden="true">
    <defs><linearGradient id={`rim-${id}`} x1="45" y1="10" x2="275" y2="310" gradientUnits="userSpaceOnUse"><stop stopColor="#fff0c8"/><stop offset=".25" stopColor="#b98a43"/><stop offset=".5" stopColor="#f2d48a"/><stop offset=".76" stopColor="#765224"/><stop offset="1" stopColor="#e8c67d"/></linearGradient></defs>
    <circle cx="160" cy="160" r="155" stroke="#0c111a" strokeWidth="10"/>
    <circle cx="160" cy="160" r="155" stroke={`url(#rim-${id})`} strokeWidth="7"/>
    <circle cx="160" cy="160" r="150" stroke="#f6dda1" strokeOpacity=".48" strokeWidth="1"/>
    {[45,90,135,180,225,270,315].map(angle=>{const [x,y]=point(angle,155);return <g key={angle}><circle cx={x} cy={y} r="2" fill="#4d351b"/><circle cx={x-.4} cy={y-.5} r=".7" fill="#ffefc2" fillOpacity=".7"/></g>;})}
  </svg>;
}

const WheelArt=forwardRef<HTMLDivElement,{prizes:WheelPrize[]}>(({prizes},ref)=>{
  const segments=wheelSegments(prizes);
  return <div className="wheel-art" aria-hidden="true">
    <div className="wheel-disc" ref={ref}><WheelFace prizes={prizes}/>
    {segments.map(prize=>{
      const angle=prize.middle*Math.PI/180;
      return <span className={`wheel-segment wheel-segment-${prize.kind}`} key={prize.position} data-wheel-middle={prize.middle} style={{left:`${50+36*Math.sin(angle)}%`,top:`${50-36*Math.cos(angle)}%`}}><span className="wheel-prize-rotation"><span className="wheel-prize-art"><WheelPrizeIcon kind={prize.kind} size={52}/></span></span></span>;
    })}</div>
    <WheelRim/>
    <div className="wheel-pointer"><span/></div>
    <div className="wheel-hub"><strong>Giro</strong><small>Grátis</small></div>
  </div>;
});
export default WheelArt;
