import { boxCatalog, fontBoxCatalog, halloweenCatalog } from './boxCatalog';
import type { BoxTheme } from './types';

export const boxLabels:Record<BoxTheme,string>={classic:'Caixa de Personalização',halloween:'Caixa de Halloween',font:'Caixa de Fontes',name:'Caixa de Cor de Nome',frame:'Caixa de Moldura'};
export const boxStateCalls:Record<BoxTheme,string>={classic:'getBoxState',halloween:'getHalloweenBoxState',font:'getFontBoxState',name:'getNameBoxState',frame:'getFrameBoxState'};
export const boxOpenCalls:Record<BoxTheme,string>={classic:'openBox',halloween:'openHalloweenBox',font:'openFontBox',name:'openNameBox',frame:'openFrameBox'};
export function catalogForBox(theme:BoxTheme){
  return theme==='halloween'?halloweenCatalog:theme==='font'?fontBoxCatalog:theme==='name'||theme==='frame'?boxCatalog.filter(item=>item.kind===theme):boxCatalog;
}
