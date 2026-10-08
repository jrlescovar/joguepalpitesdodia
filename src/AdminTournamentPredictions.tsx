import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { Check, RefreshCw, Trophy } from 'lucide-react';
import { call, errorMessage } from './backend';
import { ErrorNotice, Loading, Modal } from './components';
import { tournamentDay, tournamentTime, tournamentOptions, type TournamentOption, type AdminFinishingTournamentState, type TournamentPrediction } from './finishingTournamentTypes';
import './finishingTournament.css';

export default function AdminTournamentPredictions() {
  const [data, setData] = useState<AdminFinishingTournamentState | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [day, setDay] = useState('');
  const [game, setGame] = useState<TournamentPrediction | null>(null);
  const [busy, setBusy] = useState(false);
  const [winner, setWinner] = useState<TournamentOption | ''>('');
  const [offset, setOffset] = useState(0);
  const [now, setNow] = useState(Date.now());
  const load = useCallback(async () => {
    setLoading(true); setError('');
    try {
      const result = await call<AdminFinishingTournamentState | null>('getAdminFinishingTournament');
      setData(result);
      if (result) setDay(previous => result.predictions.some(game => game.dayId === previous) ? previous : result.predictions[0]?.dayId ?? '');
      if (result) { setOffset(result.serverTime - Date.now()); setNow(result.serverTime); }
    } catch (cause) { setError(errorMessage(cause)); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { void load(); }, [load]);
  useEffect(() => {
    const update = () => { if (document.visibilityState === 'visible') setNow(Date.now() + offset); };
    const timer = window.setInterval(update, 1000);
    document.addEventListener('visibilitychange', update);
    return () => { clearInterval(timer); document.removeEventListener('visibilitychange', update); };
  }, [offset]);
  async function settle(event: FormEvent) {
    event.preventDefault();
    if (!data || !game || busy || !winner) return;
    setBusy(true); setError(''); setSuccess('');
    try {
      const result = await call<AdminFinishingTournamentState>('settleTournamentWinner', { tournamentId: data.id, slot: game.slot, winningOptionId: winner });
      setData(result); setOffset(result.serverTime - Date.now()); setNow(result.serverTime);
      setSuccess('Resultado confirmado. Apenas os acertos e o ranking do torneio foram atualizados.'); setGame(null);
    } catch (cause) { setError(errorMessage(cause)); }
    finally { setBusy(false); }
  }
  if (loading && !data) return <Loading label="Carregando palpites do torneio…"/>;
  if (!data) return <ErrorNotice message={error || 'Nenhum torneio disponível.'} retry={() => void load()}/>;
  const days = [...new Set(data.predictions.map(prediction => prediction.dayId))].sort();
  return <section className="finishing-tournament-page admin-tournament-predictions">
    <div className="tournament-section-heading"><h2><Trophy size={20}/>{data.name}</h2><button className="icon-button" aria-label="Atualizar palpites do torneio" disabled={loading || busy} onClick={() => void load()}><RefreshCw size={18} className={loading ? 'spin' : ''}/></button></div>
    <p className="muted text-sm">{data.predictions.length ? 'Apure o resultado após o fim da partida. Cada acerto vale 1 ponto só no torneio.' : 'Os palpites serão publicados em breve.'}</p>
    <div className="tournament-day-tabs" role="group" aria-label="Dia para apurar o torneio">{days.map(value => <button type="button" key={value} aria-pressed={day === value} onClick={() => setDay(value)}>{tournamentDay(value)}</button>)}</div>
    {error && <ErrorNotice message={error}/>}{success && <p className="success-message" role="status"><Check size={17}/>{success}</p>}
    <div className="tournament-picks-grid">{data.predictions.filter(prediction => prediction.dayId === day).map(prediction => <article className="tournament-pick-card" key={prediction.slot}>
      <div className="tournament-pick-meta"><span>#{prediction.slot}</span><span>{tournamentTime(prediction.closesAt)} · Brasília</span></div>
      <h3>{prediction.homeTeam} × {prediction.awayTeam}</h3><p className="muted text-sm">{prediction.title}</p>
      {prediction.status === 'settled' ? <p className="tournament-pick-feedback correct"><Check size={15}/>{prediction.homeShots !== null && prediction.awayShots !== null ? `Finalizações: ${prediction.homeShots} × ${prediction.awayShots} · ` : ''}Resultado: {tournamentOptions.find(option => option.id === prediction.winningOptionId)?.label} · Confirmado</p>
        : <button type="button" className="secondary-button w-full" disabled={now < Date.parse(prediction.closesAt) || busy} onClick={() => { setGame(prediction); setWinner(''); setError(''); }}>Confirmar resultado</button>}
    </article>)}</div>
    <Modal className="admin-dialog" open={Boolean(game)} onOpenChange={open => { if (!open && !busy) setGame(null); }} title="Resultado do torneio" description={`Selecione quem teve mais ${data.metric === 'cards' ? 'cartões' : 'finalizações'} nos 90 minutos e acréscimos. A confirmação é definitiva e atualiza somente este torneio.`}>
      {game && <form onSubmit={settle}>
        <p className="confirm-selection">{game.homeTeam} × {game.awayTeam}</p>
        <label className="field-label" htmlFor="tournament-winner">Opção vencedora</label>
        <select id="tournament-winner" required disabled={busy} value={winner} onChange={event => setWinner(event.target.value as TournamentOption | '')}>
          <option value="">Selecione o resultado</option>
          <option value="home">Casa · {game.homeTeam}</option>
          <option value="draw">Empate</option>
          <option value="away">Fora · {game.awayTeam}</option>
        </select>
        {error && <ErrorNotice message={error}/>}
        <button className="primary-button w-full mt-4" disabled={busy || !winner}>{busy ? 'Confirmando…' : 'Confirmar resultado do torneio'}</button>
      </form>}
    </Modal>
  </section>;
}
