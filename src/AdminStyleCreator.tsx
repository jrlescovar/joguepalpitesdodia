import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { Copy, Palette, Plus, Save, Trash2 } from 'lucide-react';
import { Avatar } from './components';
import UsernameText from './UsernameText';
import { creatorStyleOptions as passStyleOptions, passStyleOptions as existingKits } from './passStyleOptions';
import { usernameFonts, type UsernameFont } from './usernameFonts';
import type { PassNameStyle } from './types';
import './supporter.css';
import './halloween.css';
import './ownerStyleVariants.css';
import './adminStyleCreator.css';
import { creatorEffectGroups, canonicalCreatorModel } from './creatorEffectModels';

type Draft={title:string;name:string;nameModel:PassNameStyle;frameModel:PassNameStyle;font:UsernameFont;colors:string[];sourceKit?:PassNameStyle;originalKit?:boolean};
const storageKey='admin-style-creator-v1';
const initial:Draft={title:'',name:'zaotips',nameModel:'lab-blue-9',frameModel:'lab-blue-9',font:'normal',colors:['#1e40af','#3b82f6','#ecfeff']};
const models=passStyleOptions;
const nameModels=models.filter(([id])=>creatorEffectGroups.name.some(group=>group[0]===id));
const frameModels=models.filter(([id])=>creatorEffectGroups.frame.some(group=>group[0]===id));
function normalizedDraft(d:Draft):Draft {return d.sourceKit?d:{...d,nameModel:canonicalCreatorModel(d.nameModel,'name'),frameModel:canonicalCreatorModel(d.frameModel,'frame')};}

function validDraft(value:unknown):value is Draft {
 const d=value as Draft;
 return !!d&&typeof d.title==='string'&&typeof d.name==='string'&&models.some(([id])=>id===d.nameModel)&&models.some(([id])=>id===d.frameModel)&&usernameFonts.some(([id])=>id===d.font)&&Array.isArray(d.colors)&&d.colors.length>=3&&d.colors.length<=6&&d.colors.every(c=>/^#[\da-f]{6}$/i.test(c));
}
function restore():Draft {try {const d=JSON.parse(localStorage.getItem(storageKey)||'null');return validDraft(d)?normalizedDraft(d):initial;}catch{return initial;}}
function loadSaved():Draft[] {try {const d=JSON.parse(localStorage.getItem(storageKey+'-saved')||'[]');return Array.isArray(d)?d.filter(validDraft).map(normalizedDraft):[];}catch{return [];}}
const colorPattern=/#(?:[\da-f]{8}|[\da-f]{6}|[\da-f]{4}|[\da-f]{3})\b|rgba?\([^)]*\)/gi;
function channels(color:string):number[] {
 if(color[0]==='#'){let h=color.slice(1);if(h.length<=4)h=h.split('').map(c=>c+c).join('');return [parseInt(h.slice(0,2),16),parseInt(h.slice(2,4),16),parseInt(h.slice(4,6),16),h.length===8?parseInt(h.slice(6,8),16)/255:1];}
 const parts=color.match(/[\d.]+/g)?.map(Number)||[];return [parts[0]||0,parts[1]||0,parts[2]||0,parts[3]??1];
}
function keyframes():Map<string,string> {
 const result=new Map<string,string>();
 const walk=(rules:CSSRuleList)=>{for(const rule of Array.from(rules)){if(rule.type===7){const r=rule as CSSKeyframesRule;result.set(r.name,r.cssText);}else if('cssRules' in rule)walk((rule as CSSGroupingRule).cssRules);}};
 for(const sheet of Array.from(document.styleSheets)){try{walk(sheet.cssRules);}catch{/* External font stylesheets do not contain our effects. */}}
 return result;
}
function previewRules(name:HTMLElement,avatar:HTMLElement,colors:string[]):string {
 const frames=keyframes();
 const make=(element:HTMLElement,pseudo:string|null,selector:string,kind:string)=>{
  const computed=getComputedStyle(element,pseudo);
  const properties=pseudo?['background-image','background-color','border-color','box-shadow','filter']:kind==='name'?['color','background-image','text-shadow','filter']:['border-color','box-shadow','background-image'];
  const palette=new Map<string,string>();
  const replace=(text:string)=>text.replace(/var\((--[\w-]+)\)/g,(whole,variable)=>computed.getPropertyValue(variable).trim()||whole).replace(colorPattern,color=>{const [r,g,b,a]=channels(color);if(a===0)return color;const key=[r,g,b].join(',');if(!palette.has(key))palette.set(key,colors[palette.size%colors.length]);const [nr,ng,nb]=channels(palette.get(key)!);return `rgba(${nr},${ng},${nb},${a})`;});
  let declarations=properties.map(property=>{
   let value=replace(computed.getPropertyValue(property));
   // Additional palette slots expand the continuous sweep; segmented masks keep their geometry.
   if(property==='background-image'&&colors.length>3&&/^(linear|conic)-gradient/.test(value)){
    const type=value.startsWith('linear')?'linear':'conic';
    const angle=type==='linear'?(value.match(/^linear-gradient\(([-.\d]+deg),/)?.[1]||'135deg')+',':'';
    const stops=kind==='name'&&computed.animationName==='rainbow-flow'?[...colors,...colors,colors[0]]:[...colors,colors[0]];
    value=`${type}-gradient(${kind==='name'&&computed.animationName==='rainbow-flow'?'90deg,':angle}${stops.join(',')})`;
   }
   return `${property}:${value}${property==='filter'||property==='text-shadow'?'':' !important'};`;
  }).join('');
  let rules='';
  const animations=computed.animationName.split(',').map((value,index)=>{const original=value.trim();if(original==='none'||!frames.has(original))return original;const custom=`creator-${kind}-${pseudo?'layer'+pseudo.replaceAll(':',''):'base'}-${index}`;rules+=replace(frames.get(original)!).replace(original,custom)+'\n';return custom;});
  declarations+=`animation-name:${animations.join(',')} !important;`;
  return `${selector}{${declarations}}\n${rules}`;
 };
 return make(name,null,'.admin-style-live .creator-name','name')+make(avatar,null,'.admin-style-live .avatar','frame')+make(avatar,'::before','.admin-style-live .avatar::before','frame')+make(avatar,'::after','.admin-style-live .avatar::after','frame');
}
export default function AdminStyleCreator(){
 const [draft,setDraft]=useState(restore),[saved,setSaved]=useState(loadSaved),[notice,setNotice]=useState(''),[rules,setRules]=useState('');
 const original=useRef<HTMLDivElement>(null);
 const pendingKit=useRef(false);
 const [kit,setKit]=useState<PassNameStyle>('halloween-clown');
 const selectableNames:[PassNameStyle,string][]=[['none','Normal'],...nameModels];
 const selectableFrames:[PassNameStyle,string][]=[['none','Sem moldura'],...frameModels];
 const nameChoices=selectableNames.some(([id])=>id===draft.nameModel)?selectableNames:[...selectableNames,models.find(([id])=>id===draft.nameModel)!];
 const frameChoices=selectableFrames.some(([id])=>id===draft.frameModel)?selectableFrames:[...selectableFrames,models.find(([id])=>id===draft.frameModel)!];
 useEffect(()=>{try{localStorage.setItem(storageKey,JSON.stringify(draft));}catch{setNotice('Não foi possível guardar o rascunho neste navegador. Copie a combinação para salvar.');}},[draft]);
 useLayoutEffect(()=>{const name=original.current?.querySelector<HTMLElement>('.creator-name'),avatar=original.current?.querySelector<HTMLElement>('.avatar');if(name&&avatar){
  if(pendingKit.current){pendingKit.current=false;const css=[getComputedStyle(name).backgroundImage,getComputedStyle(avatar,'::before').backgroundImage,getComputedStyle(avatar,'::after').backgroundImage,getComputedStyle(name).color].join(' ');const palette=Array.from(new Set((css.match(colorPattern)||[]).filter(c=>channels(c)[3]>0).map(c=>'#'+channels(c).slice(0,3).map(v=>Math.round(v).toString(16).padStart(2,'0')).join('')))).slice(0,6);while(palette.length<3)palette.push(palette[0]||'#ffffff');setDraft(d=>({...d,colors:palette}));}
  setRules(draft.originalKit?'':previewRules(name,avatar,draft.colors));
 }},[draft.nameModel,draft.frameModel,draft.colors,draft.originalKit]);
 const change=<K extends keyof Draft>(key:K,value:Draft[K])=>{setDraft(d=>({...d,[key]:value,...(['colors','nameModel','frameModel'].includes(key)?{originalKit:false}:{})}));setNotice('');};
 const preview=<><Avatar name={draft.name||'Preview'} color="#475569" borderStyle={draft.frameModel} large/><strong className={`creator-name pass-name-${draft.nameModel}`}><UsernameText name={draft.name||'Preview'} font={draft.font}/></strong></>;
 const exported=JSON.stringify({kitToEdit:draft.sourceKit??null,kitName:existingKits.find(([id])=>id===draft.sourceKit)?.[1]??null,previewName:draft.name,nameEffect:draft.nameModel,frameEffect:draft.frameModel,font:draft.font,colors:draft.colors,rgb:draft.colors.map(c=>channels(c).slice(0,3))},null,2);
 function save(){const next=[{...draft,title:draft.name||'Prévia'},...saved].slice(0,30);try{localStorage.setItem(storageKey+'-saved',JSON.stringify(next));setSaved(next);setNotice('Combinação salva neste navegador.');}catch{setNotice('Não foi possível salvar. Copie a combinação abaixo.');}}
 async function copy(){try{await navigator.clipboard.writeText(exported);setNotice('Combinação copiada. Pode colar no chat.');}catch{setNotice('Selecione e copie o texto em “Dados da combinação” abaixo.');}}
 return <section className="admin-style-creator"><header><Palette size={23}/><div><h2>Criador de nome e moldura</h2><p className="muted">Escolha os efeitos e monte sua paleta. A prévia muda na hora.</p></div></header>
 <div className="creator-layout"><section className="card creator-preview-panel"><span className="eyebrow">PRÉVIA AO VIVO</span><style>{rules}</style><div className="admin-style-live">{preview}</div><small className="muted">Seu rascunho fica guardado neste navegador.</small></section>
 <section className="card creator-controls"><div className="creator-kit-loader"><button className="primary-button" onClick={()=>{pendingKit.current=false;setRules('');setDraft({title:'',name:draft.name||'zaotips',nameModel:'none',frameModel:'none',font:'normal',colors:['#ffffff','#ffffff','#ffffff'],originalKit:false});setNotice('Novo kit criado. Escolha os efeitos e as cores para montar sua prévia.');}}><Plus size={17}/>Criar kit</button><label>Editar kit existente<select aria-label="Editar kit existente" value={kit} onChange={e=>setKit(e.target.value as PassNameStyle)}>{existingKits.filter(([id])=>id!=='none').map(([id,label])=><option key={id} value={id}>{label}</option>)}</select></label><button className="secondary-button" onClick={()=>{pendingKit.current=true;setDraft(d=>({...d,sourceKit:kit,originalKit:true,nameModel:kit,frameModel:kit,colors:[...d.colors]}));setNotice('Kit carregado. Edite a prévia e use “Copiar para o chat” para me enviar as alterações.');}}>Carregar kit</button><small className="muted">As alterações ficam na prévia. Copie para o chat quando quiser atualizar o kit no site.</small></div><label>Nome prévia<input value={draft.name} maxLength={20} onChange={e=>change('name',e.target.value)}/></label>
 <p className="muted creator-model-note">Cada modelo aparece uma vez. As cores ficam por sua conta nos seletores de cor.</p><div className="creator-models"><label>Efeito do nome<select aria-label="Efeito do nome" value={draft.nameModel} onChange={e=>change('nameModel',e.target.value as PassNameStyle)}>{nameChoices.map(([id,label])=><option key={id} value={id}>{label}</option>)}</select></label><label>Modelo da moldura<select aria-label="Modelo da moldura" value={draft.frameModel} onChange={e=>change('frameModel',e.target.value as PassNameStyle)}>{frameChoices.map(([id,label])=><option key={id} value={id}>{label}</option>)}</select></label></div>
 <label>Fonte na prévia<select aria-label="Fonte na prévia" value={draft.font} onChange={e=>change('font',e.target.value as UsernameFont)}>{usernameFonts.map(([id,label])=><option key={id} value={id}>{label}</option>)}</select></label>
 <div className="creator-palette-heading"><h3>Cores <small>{draft.colors.length}/6</small></h3><button className="secondary-button" disabled={draft.colors.length===6} onClick={()=>change('colors',[...draft.colors,'#ffffff'])}><Plus size={16}/>Adicionar cor</button></div>
 <div className="creator-colors">{draft.colors.map((color,index)=><fieldset key={index}><legend>Cor {index+1}</legend><div className="creator-color-top"><input type="color" aria-label={`Cor ${index+1}`} value={color} onChange={e=>change('colors',draft.colors.map((c,i)=>i===index?e.target.value:c))}/>{index>=3&&<button className="icon-button" aria-label={`Remover cor ${index+1}`} onClick={()=>change('colors',draft.colors.filter((_,i)=>i!==index))}><Trash2 size={15}/></button>}</div></fieldset>)}</div>
 <div className="creator-actions"><button className="primary-button" onClick={save}><Save size={17}/>Salvar combinação</button><button className="secondary-button" onClick={copy}><Copy size={17}/>Copiar para o chat</button></div>{notice&&<p role="status" className="creator-notice">{notice}</p>}
 <details><summary>Dados da combinação</summary><textarea readOnly value={exported} aria-label="Dados da combinação" rows={10}/></details></section></div>
 {saved.length>0&&<section className="card creator-saved"><h3>Combinações salvas</h3>{saved.map((item,index)=><div key={index}><button className="text-button" onClick={()=>{setDraft(item);setNotice('Combinação carregada.');}}>{item.name||'Prévia'}<span className="creator-swatches">{item.colors.map((color,i)=><i key={i} style={{background:color}}/>)}</span></button><button className="icon-button" aria-label={`Apagar combinação ${item.title}`} onClick={()=>{const next=saved.filter((_,i)=>i!==index);try{localStorage.setItem(storageKey+'-saved',JSON.stringify(next));setSaved(next);}catch{setNotice('Não foi possível apagar o rascunho.');}}}><Trash2 size={16}/></button></div>)}</section>}
 <div className="creator-original" ref={original} aria-hidden="true">{preview}</div></section>;
}
