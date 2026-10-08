import { useState } from 'react';
import { Avatar, Modal } from './components';
import UsernameText from './UsernameText';
import { fontBoxRarities, boxRarities, halloweenRarities, boxStyleLabel, isHalloweenFont } from './boxCatalog';
import { boxLabels, catalogForBox } from './boxThemes';
import type { BoxKind, BoxTheme, Profile } from './types';
import './box.css';
import './halloween.css';

const itemTabs: { kind: BoxKind; label: string }[] = [
  { kind: 'name', label: 'Cor nome' },
  { kind: 'frame', label: 'Moldura' },
  { kind: 'font', label: 'Fonte' },
];

export default function BoxHelp({ open, onOpenChange, theme='classic', profile }: { open: boolean; onOpenChange: (value: boolean) => void; theme?:BoxTheme; profile?:Profile }) {
  const themed=theme==='halloween';
  const singleKind=theme==='font'||theme==='name'||theme==='frame'?theme:null;
  const [selectedKind,setKind]=useState<BoxKind>('name');
  const kind=singleKind??selectedKind;
  const catalog=catalogForBox(theme).filter(item=>item.kind===kind).sort((a,b)=>boxRarities.findIndex(tier=>tier.id===a.rarity)-boxRarities.findIndex(tier=>tier.id===b.rarity));
  const previewName=profile?.username??'SeuNome';
  return <Modal open={open} onOpenChange={onOpenChange} title={boxLabels[theme]} className="box-catalog-dialog"><div className="box-help-content">
    <p>{theme==='name'?'Cada caixa contém uma cor de nome da caixa de personalização. Cor repetida vira XP.':theme==='frame'?'Cada caixa contém uma moldura da caixa de personalização. Moldura repetida vira XP.':theme==='font'?'Cada caixa contém uma fonte de nome. Fontes de Halloween não participam. Fonte repetida vira XP.':themed?'Cada caixa contém um item exclusivo de Halloween. Item repetido vira XP.':'Cada caixa contém uma cor de nome, moldura ou fonte. Item repetido vira XP.'}</p>
    <div className="box-odds"><h3>Chances por raridade</h3><div>{(theme==='font'?fontBoxRarities:themed?halloweenRarities:boxRarities).map(tier => <span key={tier.id} className={`box-tier box-tier-${tier.id}`}><b>{tier.label}</b><strong>{tier.chance}%</strong><small>Repetido: +{tier.duplicateXp} XP</small></span>)}</div></div>
    <section className="box-catalog" aria-label="Itens possíveis nesta caixa">
      <h3>Itens possíveis</h3>
      {!singleKind&&<div className="box-catalog-tabs" role="group" aria-label="Tipo de item">{itemTabs.map(tab=><button key={tab.kind} type="button" aria-pressed={kind===tab.kind} onClick={()=>setKind(tab.kind)}>{tab.label}</button>)}</div>}
      <div className={`box-catalog-grid box-catalog-${kind}`}>{catalog.map(item=><div key={`${item.kind}-${item.style}`} className={`box-catalog-item box-tier-${item.rarity}`}>
        <span className="box-catalog-preview">{item.kind==='frame'
          ? <Avatar name={previewName} color={profile?.avatarColor??'#3b82f6'} imageUrl={profile?.useGoogleAvatar===false?null:profile?.avatarUrl} borderStyle={item.style}/>
          : <strong className={`pass-name-${item.kind==='name'?item.style:profile?.passNameStyle??'none'}`}><UsernameText name={previewName} font={item.kind==='font'?item.style:profile?.usernameFont??'normal'}/></strong>}</span>
        <span className="box-catalog-label">{boxStyleLabel(item.style)}{item.kind==='font'&&isHalloweenFont(item.style)&&<small> · Evento</small>}</span>
        <small className="box-catalog-rarity">{boxRarities.find(tier=>tier.id===item.rarity)?.label}</small>
      </div>)}</div>
    </section>
  </div></Modal>;
}
