import { useEffect, useState } from 'react';
import { RefreshCw } from 'lucide-react';
import { call, errorMessage } from './backend';
import { ErrorNotice } from './components';

type Status = {
  enabled: boolean; mode: 'shadow' | 'automatic'; lastRunAt: string | null;
  observations: { target: { home: string; away: string; kind: string; options: { id: string; label: string }[] }; evidence: { winner: string; homeValue: number; awayValue: number } | null; status: string; issue: string | null }[];
};
export default function AutomaticResultsStatus() {
  const [data, setData] = useState<Status | null>(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  async function load() {
    setBusy(true); setError('');
    try { setData(await call<Status>('getAutomaticResultsStatus')); }
    catch (cause) { setError(errorMessage(cause)); }
    finally { setBusy(false); }
  }
  useEffect(() => { void load(); }, []);
  return <section className="card automatic-results-status">
    <div className="admin-list-heading"><h2>Apuração automática</h2><button type="button" className="icon-button" aria-label="Atualizar apuração automática" disabled={busy} onClick={() => void load()}><RefreshCw size={18}/></button></div>
    {data && <><p className="muted text-sm">{!data.enabled ? 'Aguardando configuração da API de futebol.' : data.mode === 'shadow' ? 'Modo de comparação: os resultados sugeridos não fecham bilhetes.' : 'Fechamento automático ativo para partidas clássicas e finalizações do torneio.'}</p>
      {data.lastRunAt && <p className="muted text-sm">Última consulta: {new Date(data.lastRunAt).toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' })} · Brasília</p>}
      {data.observations.length > 0 && <ul className="automatic-results-list">{data.observations.map((item, index) => {
        const result = item.evidence && (item.target.kind === 'tournament' ? { home: 'Casa', draw: 'Empate', away: 'Fora' }[item.evidence.winner] : item.target.options.find(o => o.id === item.evidence?.winner)?.label);
        return <li key={index}><strong>{item.target.home} × {item.target.away}</strong><span>{item.status === 'settled' ? 'Confirmado automaticamente' : item.status === 'suggested' ? `Sugestão: ${result}` : item.status === 'review' ? item.issue : 'Conferindo resultado final'}</span></li>;
      })}</ul>}
    </>}
    {busy && !data && <p className="muted text-sm">Consultando apuração…</p>}
    {error && <ErrorNotice message={error} retry={() => void load()}/>}
  </section>;
}
