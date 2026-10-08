import type { BoxTheme } from './types';

export const boxCarouselThemes:BoxTheme[]=['classic','font','halloween','name','frame'];
export function boxCarouselPageCount(count:number,perPage:number){return Math.ceil(count/perPage);}
export function boxCarouselPageStart(count:number,page:number,perPage:number){
  return Math.max(0,Math.min(page*perPage,count-perPage));
}
export function boxCarouselTargetPage(themes:BoxTheme[],target:BoxTheme,perPage:number){
  const index=themes.indexOf(target);
  return index<0?null:Math.min(Math.floor(index/perPage),boxCarouselPageCount(themes.length,perPage)-1);
}
