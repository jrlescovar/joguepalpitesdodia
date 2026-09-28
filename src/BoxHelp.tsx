import { Modal } from './components';
import { boxRarities } from './boxCatalog';
import './box.css';

export default function BoxHelp({ open, onOpenChange }: { open: boolean; onOpenChange: (value: boolean) => void }) {
  return <Modal open={open} onOpenChange={onOpenChange} title="Como funcionam as caixas"><div className="box-help-content"><p>Cada abertura entrega um item: nome colorido, moldura de perfil ou fonte. Todas as fontes são lendárias. Se você já tiver o mesmo item, recebe XP.</p><div className="box-odds"><h3>Chances por raridade</h3><div>{boxRarities.map(tier => <span key={tier.id} className={`box-tier box-tier-${tier.id}`}><b>{tier.label}</b><strong>{tier.chance}%</strong><small>Repetido: +{tier.duplicateXp} XP</small></span>)}</div></div></div></Modal>;
}
