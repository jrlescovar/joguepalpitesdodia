import { useState } from 'react';
import { Avatar, Modal } from './components';
import UsernameText from './UsernameText';
import { fontBoxRarities, fontBoxCatalog, boxCatalog, boxRarities, halloweenCatalog, halloweenRarities, boxStyleLabel, isHalloweenFont } from './boxCatalog';
import type { BoxKind, Profile } from './types';
import './box.css';
import './halloween.css';

const itemTabs: { kind: BoxKind; label: string }[] = [
  { kind: 'name', label: 'Cor nome' },
  { kind: 'frame', label: 'Moldura' },
  { kind: 'font', label: 'Fonte' },
];

export default function BoxHelp({ open, onOpenChange, theme='classic', profile }: { open: boolean; onOpenChange: (value: boolean) => void; theme?:'classic'|'halloween'|'font'; profile?:Profile }) {
  const themed=theme==='halloween';
  const [kind,setKind]=useState<BoxKind>(theme==='font'?'font':'name');
  const catalog=(theme==='font'?fontBoxCatalog:themed?halloweenCatalog:boxCatalog).filter(item=>item.kind===kind).sort((a,b)=>boxRarities.findIndex(tier=>tier.id===a.rarity)-boxRarities.findIndex(tier=>tier.id===b.rarity));
  const previewName=profile?.username??'SeuNome';
  return <Modal open={open} onOpenChange={onOpenChange} title={theme==='font'?'Caixa de Fontes':themed?'Caixa de Halloween':'Caixa de Personalização'} className="box-catalog-dialog"><div className="box-help-content">
    <p>{theme==='font'?'Cada caixa contém uma fonte de nome. Fontes de Halloween não participam. Fonte repetida vira XP.':themed?'Cada caixa contém um item exclusivo de Halloween. Item repetido vira XP.':'Cada caixa contém uma cor de nome, moldura ou fonte. Item repetido vira XP.'}</p>
    <div className="box-odds"><h3>Chances por raridade</h3><div>{(theme==='font'?fontBoxRarities:themed?halloweenRarities:boxRarities).map(tier => <span key={tier.id} className={`box-tier box-tier-${tier.id}`}><b>{tier.label}</b><strong>{tier.chance}%</strong><small>Repetido: +{tier.duplicateXp} XP</small></span>)}</div></div>
    <section className="box-catalog" aria-label="Itens possíveis nesta caixa">
      <h3>Itens possíveis</h3>
      <div className="box-catalog-tabs" role="group" aria-label="Tipo de item">{itemTabs.filter(tab=>theme!=='font'||tab.kind==='font').map(tab=><button key={tab.kind} type="button" aria-pressed={kind===tab.kind} onClick={()=>setKind(tab.kind)}>{tab.label}</button>)}</div>
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
