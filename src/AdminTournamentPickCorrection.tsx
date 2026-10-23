import { useEffect, useRef, useState } from 'react';
import { Check, Pencil, RefreshCw } from 'lucide-react';
import { call, errorMessage } from './backend';
import { ErrorNotice, Modal } from './components';
import { tournamentDay, tournamentOptionsFor, type TournamentMetric, type TournamentSummary, tournamentTime, type TournamentOption, type TournamentPrediction } from './finishingTournamentTypes';
import TournamentSelector from './TournamentSelector';
import type { Profile } from './types';

type PlayerTournament = { id: string; name: string; metric?: TournamentMetric; availableTournaments?: TournamentSummary[]; enrolled: boolean; correctAnswers: number; predictions: TournamentPrediction[] };

export default function AdminTournamentPickCorrection({ profile }: { profile: Profile }) {
  const [tournamentId, setTournamentId] = useState<string | null>(null);
  const [data, setData] = useState<PlayerTournament | null>(null);
  const [day, setDay] = useState('');
  const [selected, setSelected] = useState<{ game: TournamentPrediction; optionId: TournamentOption } | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const request = useRef(0);
  const saving = useRef(false);

  async function load() {
    const version = ++request.current;
    setLoading(true); setError(''); setSuccess(''); setSelected(null);
    try {
      const state = await call<PlayerTournament | null>('getAdminPlayerTournamentPicks', { uid: profile.uid, tournamentId });
      if (version === request.current) {
        setData(state);
        setDay(current => state?.predictions.some(game => game.dayId === current) ? current : state?.predictions[0]?.dayId ?? '');
      }
    } catch (cause) { if (version === request.current) setError(errorMessage(cause)); }
    finally { if (version === request.current) setLoading(false); }
  }
  useEffect(() => { void load(); return () => { ++request.current; }; }, [profile.uid, tournamentId]);

  async function save() {
    if (!selected || !data || saving.current) return;
    saving.current = true;
    const version = request.current;
    setBusy(true); setError(''); setSuccess('');
    try {
      const state = await call<PlayerTournament>('adminSaveTournamentPick', {
        uid: profile.uid, tournamentId: data.id, slot: selected.game.slot,
        optionId: selected.optionId, expectedOptionId: selected.game.myOptionId,
      });
      if (version === request.current) {
        setData(state); setSelected(null);
        setSuccess(selected.game.status === 'settled'
          ? 'Palpite salvo. Acertos e ranking do torneio atualizados.'
          : 'Palpite salvo. O acerto será calculado quando sair o resultado.');
      }
    } catch (cause) { if (version === request.current) setError(errorMessage(cause)); }
    finally { saving.current = false; if (version === request.current) setBusy(false); }
  }

  const options = tournamentOptionsFor(data?.metric, selected?.game);
  const label = (game: TournamentPrediction, id: TournamentOption | null) => tournamentOptionsFor(data?.metric, game).find(option => option.id === id)?.label ?? 'Sem palpite';
  const days = [...new Set(data?.predictions.map(game => game.dayId) ?? [])].sort();
  return <section className="admin-pick-card admin-tournament-picks" aria-label="Palpites do torneio do jogador" aria-busy={loading}>
    {data && <TournamentSelector tournaments={data.availableTournaments} value={data.id} disabled={loading || busy} onChange={setTournamentId}/>}
    <div className="admin-pick-heading"><Pencil size={18}/><strong>Editar palpites do torneio</strong></div>
    <p>Escolha a partida e corrija o palpite de {profile.username}.</p>
    <button type="button" className="secondary-button admin-tournament-reload" disabled={loading || busy} onClick={() => void load()}><RefreshCw size={16}/>Recarregar lista</button>
    {loading ? <p role="status">Carregando palpites do torneio…</p> : !error && (!data ? <p className="muted">Nenhum torneio disponível.</p> : !data.enrolled ? <p className="muted">Este jogador não está inscrito em {data.name}.</p> : <>
      <p><strong>{data.name}</strong> · {data.correctAnswers} {data.correctAnswers === 1 ? 'acerto' : 'acertos'}</p>
      {days.length > 0 ? <>
        <label className="field-label" htmlFor="admin-tournament-day">Dia das partidas</label>
        <select id="admin-tournament-day" value={day} disabled={busy} onChange={event => { setDay(event.target.value); setSuccess(''); }}>
          {days.map(value => <option key={value} value={value}>{tournamentDay(value)}</option>)}
        </select>
        {data.predictions.filter(game => game.dayId === day).map(game => <div className="admin-pick-row" key={game.slot}>
          <div><strong>{game.homeTeam} x {game.awayTeam}</strong>
            <span>{game.title} · {tournamentTime(game.closesAt)}</span>
            <span>Palpite: {label(game, game.myOptionId)}{game.myResult ? ` · ${game.myResult === 'correct' ? 'Acertou' : 'Não acertou'}` : ''}</span>
            {game.winningOptionId && <span>Resultado: {label(game, game.winningOptionId)}</span>}
          </div>
          <button type="button" className="secondary-button" disabled={busy} onClick={() => { setError(''); setSelected({ game, optionId: game.myOptionId ?? 'home' }); }}>{game.myOptionId ? 'Corrigir' : 'Adicionar'}</button>
        </div>)}
      </> : <p className="muted">As partidas deste torneio ainda não foram publicadas.</p>}
    </>)}
    {error && !selected && <ErrorNotice message={error}/>}
    {success && <p className="success-message" role="status"><Check size={18}/>{success}</p>}
    <Modal className="admin-dialog" open={Boolean(selected)} dismissible={!busy} onOpenChange={open => { if (!open && !busy) setSelected(null); }} title={selected?.game.myOptionId ? 'Corrigir palpite do torneio' : 'Adicionar palpite do torneio'} description={`A alteração será registrada para ${profile.username}. Os acertos e o ranking do torneio serão recalculados conforme o resultado oficial.`}>
      {selected && <div className="admin-pick-review">
        <strong>{selected.game.homeTeam} x {selected.game.awayTeam}</strong>
        <p>{selected.game.title}</p>
        <p>Palpite atual: {label(selected.game, selected.game.myOptionId)}</p>
        <label className="field-label" htmlFor="admin-tournament-option">Novo palpite</label>
        <select id="admin-tournament-option" value={selected.optionId} disabled={busy} onChange={event => setSelected({ ...selected, optionId: event.target.value as TournamentOption })}>
          {options.map(option => <option key={option.id} value={option.id}>{option.label}</option>)}
        </select>
        {selected.game.winningOptionId ? <p>Resultado oficial: {label(selected.game, selected.game.winningOptionId)}. Este palpite valerá {selected.optionId === selected.game.winningOptionId ? '1 acerto' : '0 acertos'}.</p> : <p>O acerto será calculado quando o resultado for confirmado.</p>}
      </div>}
      {error && <ErrorNotice message={error}/>}
      <div className="admin-review-actions"><button type="button" className="secondary-button" disabled={busy} onClick={() => setSelected(null)}>Voltar</button><button type="button" className="primary-button" disabled={busy || !selected || selected.optionId === selected.game.myOptionId} onClick={() => void save()}>{busy ? 'Salvando…' : 'Salvar palpite'}</button></div>
    </Modal>
  </section>;
}
