import { Modal } from './components';
import { boxRarities, halloweenCatalog, boxStyleLabel } from './boxCatalog';
import './box.css';

export default function BoxHelp({ open, onOpenChange, theme='classic' }: { open: boolean; onOpenChange: (value: boolean) => void; theme?:'classic'|'halloween' }) {
  const themed=theme==='halloween';
  return <Modal open={open} onOpenChange={onOpenChange} title={themed?'Caixa de Halloween':'Como funcionam as caixas'}><div className="box-help-content"><p>{themed?'Use uma caixa do seu saldo para receber uma cor de nome, moldura, fonte ou fundo da coleção de Halloween. Item repetido vira XP.':'Cada abertura entrega um item: nome colorido, moldura de perfil ou fonte. Se você já tiver o mesmo item, recebe XP.'}</p><div className="box-odds"><h3>Chances por raridade</h3><div>{boxRarities.map(tier => <span key={tier.id} className={`box-tier box-tier-${tier.id}`}><b>{tier.label}</b><strong>{tier.chance}%</strong><small>Repetido: +{tier.duplicateXp} XP</small></span>)}</div></div>{themed&&<div className="halloween-catalog"><h3>Itens possíveis</h3>{halloweenCatalog.map(item=><span key={`${item.kind}-${item.style}`}>{item.kind==='name'?'Nome':item.kind==='frame'?'Moldura':item.kind==='font'?'Fonte':'Fundo'} · {boxStyleLabel(item.style)}</span>)}</div>}</div></Modal>;
}
