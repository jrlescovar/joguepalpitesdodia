import type { CSSProperties } from 'react';
import type { BoxTheme } from './types';

export type CustomizationBoxTheme = BoxTheme|'legendary';
const caseImages:Record<CustomizationBoxTheme,string> = {
  legendary:'/midia/caixas/legendary-gold-20261015.webp',
  frame: '/midia/caixas/frame-case-front-20261014.webp',
  name: '/midia/caixas/name-clean-20261014.webp',
  font: '/midia/caixas/font-spray-20261014.webp',
  classic: '/midia/caixas/classic-black-colors-20261014.webp',
  halloween: '/midia/caixas/halloween-case-20261014.webp',
};
// Match the visible chest width, not each file's transparent canvas.
const caseVisibleWidth:Record<CustomizationBoxTheme,number>={
  halloween:504/512,classic:464/512,font:476/512,
  frame:498/512,name:496/512,legendary:629/630,
};

export default function CustomizationBoxIcon({theme='classic',size=64,className,opening=false}: {
  theme?:CustomizationBoxTheme;size?:number;className?:string;opening?:boolean;
}) {
  const sceneStyle={
    width:`${100*caseVisibleWidth.halloween/caseVisibleWidth[theme]}%`,
    '--case-seam':theme==='name'?'35.3%':theme==='font'?'33.6%':theme==='classic'?'28.6%':theme==='halloween'?'32%':'34.2%',
    aspectRatio:theme==='font'||theme==='classic'||theme==='legendary'?'2 / 1':'3 / 2',
  } as CSSProperties;
  return <span className={`customization-case-image${className?` ${className}`:''}${opening?' case-opening':''}`}
    style={{'--case-size':`${size}px`} as CSSProperties} aria-hidden="true" data-box-icon={theme}>
    <span className="case-scene" style={sceneStyle}>
      <span className="case-cavity"/>
      <img className="case-body" src={caseImages[theme]} alt="" decoding="async" draggable={false}/>
      <img className="case-lid" src={caseImages[theme]} alt="" decoding="async" draggable={false}/>
    </span>
  </span>;
}
