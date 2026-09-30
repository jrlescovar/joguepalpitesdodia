import { useEffect, useState } from 'react';
import { call, errorMessage } from './backend';
import { ErrorNotice } from './components';
import './profileRetrospective.css';

type Day = { dayId: string; greens: number; points: number };
type Metric = 'greens' | 'points';
const dayFormatter = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: '2-digit', timeZone: 'UTC' });
function shortDay(dayId: string) { return dayFormatter.format(new Date(`${dayId}T12:00:00Z`)); }

function Chart({ days, metric, title }: { days: Day[]; metric: Metric; title: string }) {
  const max = Math.max(1, ...days.map(day => day[metric]));
  const total = days.reduce((sum, day) => sum + day[metric], 0);
  return <div className={`retrospective-chart retrospective-${metric}`}>
    <div className="retrospective-chart-heading"><strong>{title}</strong><span>{total.toLocaleString('pt-BR')} {metric === 'greens' ? 'acertos' : 'pts'}</span></div>
    <div className="retrospective-bars" role="img" aria-label={`${title}: ${total} no período de ${shortDay(days[0].dayId)} a ${shortDay(days.at(-1)!.dayId)}`} style={{ gridTemplateColumns: `repeat(${days.length}, minmax(0, 1fr))` }}>
      {days.map(day => <span key={day.dayId} className={`retrospective-bar${day[metric] === 0 ? ' is-empty' : ''}`} style={{ height: `${day[metric] === 0 ? 2 : Math.max(5, day[metric] / max * 100)}%` }} title={`${shortDay(day.dayId)}: ${day[metric]} ${metric === 'greens' ? 'acertos' : 'pts'}`}/>)}
    </div>
    <div className="retrospective-dates"><span>{shortDay(days[0].dayId)}</span><span>{shortDay(days.at(-1)!.dayId)}</span></div>
  </div>;
}

export default function ProfileRetrospective({ refreshTick }: { refreshTick: number }) {
  const [period, setPeriod] = useState<7 | 30>(7);
  const [data, setData] = useState<Day[] | null>(null);
  const [error, setError] = useState('');
  const [retry, setRetry] = useState(0);
  useEffect(() => {
    let active = true;
    setError('');
    void call<Day[]>('getMyRetrospective')
      .then(days => { if (active) setData(days); })
      .catch(cause => { if (active) setError(errorMessage(cause)); });
    return () => { active = false; };
  }, [refreshTick, retry]);

  const days = data?.slice(-period) ?? [];
  return <section className="card profile-retrospective" aria-label="Retrospectiva pessoal">
    <div className="retrospective-header"><div><h2>Sua retrospectiva</h2><p>Acertos e PontosRank ganhos nos palpites</p></div><div className="retrospective-period" role="group" aria-label="Período da retrospectiva"><button type="button" className={period === 7 ? 'active' : ''} aria-pressed={period === 7} onClick={() => setPeriod(7)}>7 dias</button><button type="button" className={period === 30 ? 'active' : ''} aria-pressed={period === 30} onClick={() => setPeriod(30)}>30 dias</button></div></div>
    {error && <ErrorNotice message={error} retry={() => setRetry(value => value + 1)}/>}
    {!data && !error && <p className="muted" role="status">Carregando retrospectiva…</p>}
    {days.length > 0 && <div className="retrospective-charts"><Chart days={days} metric="greens" title="Acertos"/><Chart days={days} metric="points" title="Pontos"/></div>}
  </section>;
}
