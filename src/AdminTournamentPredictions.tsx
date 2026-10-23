import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react';
import { Check, RefreshCw, Trophy } from 'lucide-react';
import { call, errorMessage } from './backend';
import { ErrorNotice, Loading, Modal } from './components';
import { tournamentDay, tournamentTime, tournamentOptionsFor, type TournamentOption, type AdminFinishingTournamentState, type TournamentPrediction } from './finishingTournamentTypes';
import TournamentSelector from './TournamentSelector';
import './finishingTournament.css';

export default function AdminTournamentPredictions() {
  const request = useRef(0);
  const [tournamentId, setTournamentId] = useState<string | null>(null);
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
    const version = ++request.current;
    setLoading(true); setError('');
    try {
      const result = await call<AdminFinishingTournamentState | null>('getAdminFinishingTournament', { tournamentId });
      if (version !== request.current) return;
      setData(result);
      if (result) setDay(previous => result.predictions.some(game => game.dayId === previous) ? previous : result.predictions[0]?.dayId ?? '');
      if (result) { setOffset(result.serverTime - Date.now()); setNow(result.serverTime); }
    } catch (cause) { if (version === request.current) setError(errorMessage(cause)); }
    finally { if (version === request.current) setLoading(false); }
  }, [tournamentId]);
  useEffect(() => { void load(); return () => { ++request.current; }; }, [load]);
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
  if (loading && (!data || (tournamentId !== null && data.id !== tournamentId))) return <Loading label="Carregando palpites do torneio…"/>;
  if (!data) return <ErrorNotice message={error || 'Nenhum torneio disponível.'} retry={() => void load()}/>;
  const options = tournamentOptionsFor(data.metric, game);
  const days = [...new Set(data.predictions.map(prediction => prediction.dayId))].sort();
  return <section className="finishing-tournament-page admin-tournament-predictions">
    <TournamentSelector tournaments={data.availableTournaments} value={data.id} disabled={loading || busy} onChange={id => { setGame(null); setSuccess(''); setTournamentId(id); }}/>
    <div className="tournament-section-heading"><h2><Trophy size={20}/>{data.name}</h2><button className="icon-button" aria-label="Atualizar palpites do torneio" disabled={loading || busy} onClick={() => void load()}><RefreshCw size={18} className={loading ? 'spin' : ''}/></button></div>
    <p className="muted text-sm">{data.predictions.length ? 'Apure o resultado após o fim da partida. Cada acerto vale 1 ponto só no torneio.' : 'Os palpites serão publicados em breve.'}</p>
    <div className="tournament-day-tabs" role="group" aria-label="Dia para apurar o torneio">{days.map(value => <button type="button" key={value} aria-pressed={day === value} onClick={() => setDay(value)}>{tournamentDay(value)}</button>)}</div>
    {error && <ErrorNotice message={error}/>}{success && <p className="success-message" role="status"><Check size={17}/>{success}</p>}
    <div className="tournament-picks-grid">{data.predictions.filter(prediction => prediction.dayId === day).map(prediction => <article className="tournament-pick-card" key={prediction.slot}>
      <div className="tournament-pick-meta"><span>#{prediction.slot}</span><span>{tournamentTime(prediction.closesAt)} · Brasília</span></div>
      <h3>{prediction.homeTeam} × {prediction.awayTeam}</h3><p className="muted text-sm">{prediction.title}</p>
      {prediction.rules && <p className="muted text-sm">{prediction.rules}</p>}
      {prediction.status === 'settled' ? <p className="tournament-pick-feedback correct"><Check size={15}/>{prediction.homeShots !== null && prediction.awayShots !== null ? `${data.metric === 'classic' ? 'Placar' : data.metric === 'cards' ? 'Cartões' : 'Finalizações'}: ${prediction.homeShots} × ${prediction.awayShots} · ` : ''}Resultado: {tournamentOptionsFor(data.metric, prediction).find(option => option.id === prediction.winningOptionId)?.label} · Confirmado</p>
        : <button type="button" className="secondary-button w-full" disabled={now < Date.parse(prediction.closesAt) || busy} onClick={() => { setGame(prediction); setWinner(''); setError(''); }}>Confirmar resultado</button>}
    </article>)}</div>
    <Modal className="admin-dialog" open={Boolean(game)} onOpenChange={open => { if (!open && !busy) setGame(null); }} title="Resultado do torneio" description={data.metric === 'mixed' ? 'Selecione o resultado deste palpite conforme a regra indicada. A confirmação é definitiva e atualiza somente este torneio.' : data.metric === 'classic' ? 'Selecione Casa, X ou Fora conforme o placar final dos 90 minutos e acréscimos. A confirmação é definitiva e atualiza somente este torneio.' : `Selecione quem teve mais ${data.metric === 'cards' ? 'cartões' : 'finalizações'} nos 90 minutos e acréscimos. A confirmação é definitiva e atualiza somente este torneio.`}>
      {game && <form onSubmit={settle}>
        <p className="confirm-selection">{game.homeTeam} × {game.awayTeam}</p>
        {data.metric === 'mixed' && <><p>{game.title}</p><p className="muted text-sm">{game.rules}</p></>}
        <label className="field-label" htmlFor="tournament-winner">Opção vencedora</label>
        <select id="tournament-winner" required disabled={busy} value={winner} onChange={event => setWinner(event.target.value as TournamentOption | '')}>
          <option value="">Selecione o resultado</option>
          {options.map(option => <option key={option.id} value={option.id}>{game.options ? option.label : option.id === 'home' ? `Casa · ${game.homeTeam}` : option.id === 'away' ? `Fora · ${game.awayTeam}` : data.metric === 'classic' ? 'X · Empate' : 'Empate'}</option>)}
        </select>
        {error && <ErrorNotice message={error}/>}
        <button className="primary-button w-full mt-4" disabled={busy || !winner}>{busy ? 'Confirmando…' : 'Confirmar resultado do torneio'}</button>
      </form>}
    </Modal>
  </section>;
}
