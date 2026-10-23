import { useEffect, useState } from 'react';
import { Check, ChevronLeft, ChevronRight, Clock3, History, Minus, X } from 'lucide-react';
import { call, errorMessage } from './backend';
import { brasiliaDate, ErrorNotice } from './components';
import type { Prediction } from './types';
import { dailyOptionLabel } from './dailyGameDisplay';

export default function RecentResults({ refreshTick }: { refreshTick: number }) {
  const [results, setResults] = useState<Prediction[] | null>(null);
  const [error, setError] = useState('');
  const [unavailable, setUnavailable] = useState(false);
  const [retry, setRetry] = useState(0);
  const [selectedDay, setSelectedDay] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    call<Prediction[]>('getRecentResults')
      .then(rows => { if (active) { setResults(rows); setError(''); setUnavailable(false); } })
      .catch(cause => {
        if (!active) return;
        if ((cause as { code?: string }).code === 'PGRST202') setUnavailable(true);
        else setError(errorMessage(cause));
      });
    return () => { active = false; };
  }, [refreshTick, retry]);

  const days = [...new Set(results?.map(game => game.dayId) ?? [])].sort((a, b) => b.localeCompare(a));
  const day = selectedDay && days.includes(selectedDay) ? selectedDay : days[0];
  const dayIndex = days.indexOf(day);
  const dayResults = results?.filter(game => game.dayId === day) ?? [];
  const greens = dayResults.filter(game => game.myPickStatus === 'green').length;
  const reds = dayResults.filter(game => game.myPickStatus === 'red').length;
  if (results === null && !error && !unavailable) return null;
  return <section id="resultados-anteriores" className="recent-results" aria-label="Resultados anteriores">
    <div className="section-heading"><h2>Resultados anteriores</h2><History size={17} aria-hidden="true"/></div>
    {error && <ErrorNotice message={error} retry={() => setRetry(value => value + 1)}/>}
    {unavailable && <div className="card recent-results-empty">Resultados temporariamente indisponíveis.</div>}
    {!error && results?.length === 0 && <div className="card recent-results-empty"><Clock3 size={18}/> Os resultados de hoje aparecerão aqui quando forem confirmados.</div>}
    {day && <section className="card recent-results-day" aria-label={`Resultados de ${brasiliaDate(day)}`}>
      <div className="recent-day-nav"><button type="button" aria-label="Dia anterior" disabled={dayIndex >= days.length - 1} onClick={() => setSelectedDay(days[dayIndex + 1])}><ChevronLeft size={20}/></button><div className="recent-day-heading" aria-live="polite" aria-atomic="true"><h3>{brasiliaDate(day)}</h3><p>{dayResults.length} resultados{greens + reds > 0 && <><span aria-hidden="true"> · </span><span className="recent-summary-green">{greens} greens</span><span aria-hidden="true"> · </span><span className="recent-summary-red">{reds} reds</span></>}</p></div><button type="button" aria-label="Dia seguinte" disabled={dayIndex <= 0} onClick={() => setSelectedDay(days[dayIndex - 1])}><ChevronRight size={20}/></button></div>
      <div className="recent-results-grid">{dayResults.map(game => {
        const winner = game.options.find(option => option.id === game.winningOptionId);
        const fixture = game.title.match(/^(.*?)\s*\(([^()]+\s+(?:x|×|vs\.?)\s+[^()]+)\)\s*$/i);
        const statusLabel = game.myPickStatus === 'green' ? 'Green' : game.myPickStatus === 'red' ? 'Red' : 'Sem palpite';
        return <div className={`recent-result-row result-${game.myPickStatus ?? 'neutral'}`} key={`${day}-${game.slot}`}>
          <span className="recent-result-check" aria-hidden="true">{game.myPickStatus === 'red' ? <X size={16}/> : game.myPickStatus === 'green' ? <Check size={16}/> : <Minus size={16}/>}</span>
          <div className="recent-result-copy"><small>{statusLabel}</small><strong>{fixture ? fixture[1] : game.title}</strong>{fixture && <span className="recent-result-fixture">{fixture[2]}</span>}</div>
          <span className="recent-result-winner"><small>Resultado</small><b>{winner ? dailyOptionLabel(game, winner) : 'Confirmado'}</b></span>
        </div>;
      })}</div>
    </section>}
  </section>;
}
