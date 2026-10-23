import { ChevronLeft, ChevronRight } from 'lucide-react';
import type { TournamentSummary } from './finishingTournamentTypes';

export default function TournamentSelector({ tournaments, value, disabled, onChange, perPage = 1 }: { perPage?: number; tournaments?: TournamentSummary[]; value: string; disabled?: boolean; onChange: (id: string) => void }) {
  if (!tournaments || tournaments.length <= perPage) return null;
  const selected = tournaments.findIndex(tournament => tournament.id === value);
  if (selected < 0) return null;
  const pages = Array.from({length:Math.ceil(tournaments.length/perPage)},(_,page)=>tournaments.slice(page*perPage,(page+1)*perPage));
  const index = Math.floor(selected/perPage);
  return <nav className="tournament-selector" aria-label="Navegar entre torneios">
    <button type="button" aria-label="Torneio anterior" disabled={disabled || index === 0} onClick={() => onChange(pages[index - 1][0].id)}><ChevronLeft size={20} aria-hidden="true"/></button>
    <div className="tournament-selector-dots" aria-label="Escolher torneio">
      {pages.map((page, dotIndex) => <button key={page[0].id} type="button" aria-label={`Ir para ${page.map(item=>item.name).join(" e ")}`} aria-current={dotIndex === index ? 'true' : undefined} disabled={disabled} onClick={() => onChange(page[0].id)}><span aria-hidden="true"/></button>)}
    </div>
    <button type="button" aria-label="Próximo torneio" disabled={disabled || index === pages.length - 1} onClick={() => onChange(pages[index + 1][0].id)}><ChevronRight size={20} aria-hidden="true"/></button>
  </nav>;
}
