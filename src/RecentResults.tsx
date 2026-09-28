import { useEffect, useState } from 'react';
import { Check, ChevronLeft, ChevronRight, Clock3, History, X } from 'lucide-react';
import { call, errorMessage } from './backend';
import { brasiliaDate, ErrorNotice } from './components';
import type { Prediction } from './types';

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
  if (results === null && !error && !unavailable) return null;
  return <section id="resultados-anteriores" className="recent-results" aria-label="Resultados anteriores">
    <div className="section-heading"><h2>Resultados anteriores</h2><History size={17}/></div>
    {error && <ErrorNotice message={error} retry={() => setRetry(value => value + 1)}/>}
    {unavailable && <div className="card recent-results-empty">Resultados temporariamente indisponíveis.</div>}
    {!error && results?.length === 0 && <div className="card recent-results-empty"><Clock3 size={18}/> Os resultados de hoje aparecerão aqui quando forem confirmados.</div>}
    {day && <section className="card recent-results-day" aria-label={`Resultados de ${brasiliaDate(day)}`}>
      <div className="recent-day-nav"><button type="button" aria-label="Dia anterior" disabled={dayIndex >= days.length - 1} onClick={() => setSelectedDay(days[dayIndex + 1])}><ChevronLeft size={20}/></button><h3 aria-live="polite">{brasiliaDate(day)}</h3><button type="button" aria-label="Dia seguinte" disabled={dayIndex <= 0} onClick={() => setSelectedDay(days[dayIndex - 1])}><ChevronRight size={20}/></button></div>
      {results?.filter(game => game.dayId === day).map(game => {
        const winner = game.options.find(option => option.id === game.winningOptionId);
        return <div className={`recent-result-row result-${game.myPickStatus ?? 'neutral'}`} key={`${day}-${game.slot}`}>
          <span className="recent-result-check">{game.myPickStatus === 'red' ? <X size={16}/> : <Check size={16}/>}</span>
          <div><small>{game.slot === 0 ? 'Palpites do Dia' : `Palpite Extra ${game.slot}`}</small><strong>{game.title}</strong></div>
          <span className="recent-result-winner">{winner?.label ?? 'Resultado confirmado'}</span>
        </div>;
      })}
    </section>}
  </section>;
}
