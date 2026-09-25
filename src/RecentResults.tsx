import { useEffect, useState } from 'react';
import { Check, Clock3, Trophy } from 'lucide-react';
import { call, errorMessage } from './backend';
import { brasiliaDate, ErrorNotice } from './components';
import type { Prediction } from './types';

export default function RecentResults({ refreshTick }: { refreshTick: number }) {
  const [results, setResults] = useState<Prediction[] | null>(null);
  const [error, setError] = useState('');
  const [unavailable, setUnavailable] = useState(false);
  const [retry, setRetry] = useState(0);

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

  const days = [...new Set(results?.map(game => game.dayId) ?? [])];
  if (results === null && !error && !unavailable) return null;
  return <section id="resultados-anteriores" className="recent-results" aria-label="Resultados anteriores">
    <div className="section-heading"><h2>Resultados anteriores</h2><Trophy size={17}/></div>
    {error && <ErrorNotice message={error} retry={() => setRetry(value => value + 1)}/>}
    {unavailable && <div className="card recent-results-empty">Resultados temporariamente indisponíveis.</div>}
    {!error && results?.length === 0 && <div className="card recent-results-empty"><Clock3 size={18}/> Os resultados de hoje aparecerão aqui quando forem confirmados.</div>}
    {days.map(day => <section className="card recent-results-day" key={day} aria-label={`Resultados de ${brasiliaDate(day)}`}>
      <h3>{brasiliaDate(day)}</h3>
      {results?.filter(game => game.dayId === day).map(game => {
        const winner = game.options.find(option => option.id === game.winningOptionId);
        return <div className="recent-result-row" key={`${day}-${game.slot}`}>
          <span className="recent-result-check"><Check size={16}/></span>
          <div><small>{game.slot === 0 ? 'Aposta do Dia' : `Aposta Extra ${game.slot}`}</small><strong>{game.title}</strong></div>
          <span className="recent-result-winner">{winner?.label ?? 'Resultado confirmado'}</span>
        </div>;
      })}
    </section>)}
  </section>;
}
