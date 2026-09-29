import { useEffect, useState } from 'react';
import { Check, Pencil } from 'lucide-react';
import { call, errorMessage } from './backend';
import { ErrorNotice, Modal } from './components';
import type { Profile } from './types';

type AdminPick = {
  dayId: string;
  slot: number;
  title: string;
  options: { id: string; label: string; rankPoints?: number }[];
  winningOptionId: string | null;
  predictionStatus: 'open' | 'settling' | 'settled';
  closesAt: string;
  optionId: string | null;
  status: 'pending' | 'green' | 'red' | null;
};

const today = () => new Intl.DateTimeFormat('sv-SE', { timeZone: 'America/Sao_Paulo' }).format(new Date());

export default function AdminPickCorrection({ profile, onCorrect }: { profile: Profile; onCorrect: () => Promise<void> }) {
  const [day, setDay] = useState(today);
  const [picks, setPicks] = useState<AdminPick[]>([]);
  const [selected, setSelected] = useState<{ pick: AdminPick; optionId: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    let active = true;
    setPicks([]); setError(''); setSuccess(''); setSelected(null);
    call<AdminPick[]>('getAdminPicksForDay', { uid: profile.uid, day })
      .then(rows => { if (active) setPicks(rows); })
      .catch(cause => { if (active) setError(errorMessage(cause)); });
    return () => { active = false; };
  }, [profile.uid, day]);

  async function correct() {
    if (!selected) return;
    setBusy(true); setError(''); setSuccess('');
    try {
      await call(selected.pick.optionId?'adminCorrectPick':'adminAddPick', {
        uid: profile.uid, dayId: selected.pick.dayId, slot: selected.pick.slot, optionId: selected.optionId,
      });
      const [rows] = await Promise.all([
        call<AdminPick[]>('getAdminPicksForDay', { uid: profile.uid, day }),
        onCorrect(),
      ]);
      setPicks(rows);
      setSelected(null);
      setSuccess('Palpite salvo. Resultado e pontos do jogador atualizados.');
    } catch (cause) { setError(errorMessage(cause)); } finally { setBusy(false); }
  }

  const optionLabel = (pick: AdminPick, id: string | null) => pick.options.find(option => option.id === id)?.label ?? '—';
  const chosen = selected?.pick.options.find(option => option.id === selected.optionId);

  return <section className="admin-pick-card" aria-label="Corrigir palpites do jogador">
    <div className="admin-pick-heading"><Pencil size={18}/><strong>Adicionar ou corrigir palpite</strong></div>
    <p>Escolha a data e o palpite de {profile.username}. A mudança vale somente para este jogador.</p>
    <label className="field-label" htmlFor="admin-pick-day">Data do palpite</label>
    <input id="admin-pick-day" type="date" value={day} max={today()} onChange={event => setDay(event.target.value)}/>
    {picks.length === 0 && !error && <p className="muted">Nenhuma aposta disponível nessa data.</p>}
    {picks.map(pick => {
      const closed = Date.parse(pick.closesAt) <= Date.now() && pick.predictionStatus !== 'settling';
      return <div className="admin-pick-row" key={`${pick.dayId}-${pick.slot}`}>
        <div><strong>{pick.slot === 0 ? 'Palpites do Dia' : `Palpite Extra ${pick.slot}`}: {pick.title}</strong>
          <span>Palpite: {optionLabel(pick, pick.optionId)} · {pick.status === 'green' ? 'Green' : pick.status === 'red' ? 'Red' : pick.optionId ? 'Em jogo' : 'Sem palpite'}</span>
          {pick.winningOptionId && <span>Resultado: {optionLabel(pick, pick.winningOptionId)}</span>}
        </div>
        <button type="button" className="secondary-button" disabled={!closed || busy} onClick={() => setSelected({ pick, optionId: pick.optionId??pick.options[0]?.id??'' })}>
          {closed ? pick.optionId?'Corrigir':'Adicionar' : 'Aguarde o fim'}
        </button>
      </div>;
    })}
    {error && !selected && <ErrorNotice message={error}/>}
    {success && <p className="success-message" role="status"><Check size={18}/>{success}</p>}
    <Modal className="admin-dialog" open={Boolean(selected)} onOpenChange={open => { if (!open && !busy) setSelected(null); }} title={selected?.pick.optionId?"Confirmar correção do palpite":"Adicionar palpite do jogador"} description={`A correção de ${profile.username} será registrada e, se houver resultado, greens, reds, XP e PontosRank serão ajustados.`}>
      {selected && <div className="admin-pick-review">
        <strong>{selected.pick.title}</strong>
        <p>Palpite atual: {optionLabel(selected.pick, selected.pick.optionId)}</p>
        <label className="field-label" htmlFor="admin-correct-option">Novo palpite</label>
        <select id="admin-correct-option" value={selected.optionId} onChange={event => setSelected({ ...selected, optionId: event.target.value })}>
          {selected.pick.options.map(option => <option key={option.id} value={option.id}>{option.label}{option.rankPoints ? ` · ${option.rankPoints} pts` : ''}</option>)}
        </select>
        {selected.pick.winningOptionId && <p>Resultado oficial: {optionLabel(selected.pick, selected.pick.winningOptionId)}. Novo status: {selected.optionId === selected.pick.winningOptionId ? 'green' : 'red'}{chosen?.rankPoints && selected.optionId === selected.pick.winningOptionId ? ` · ${chosen.rankPoints} PontosRank` : ''}.</p>}
        {!selected.pick.winningOptionId && <p>O resultado ainda não foi definido. Os pontos serão calculados quando o palpite for concluído.</p>}
      </div>}
      {error && <ErrorNotice message={error}/>}
      <div className="admin-review-actions"><button type="button" className="secondary-button" disabled={busy} onClick={() => setSelected(null)}>Voltar</button><button type="button" className="primary-button" disabled={busy || !selected || selected.optionId === selected.pick.optionId} onClick={() => void correct()}>{busy ? 'Salvando…' : selected?.pick.optionId?'Confirmar correção':'Confirmar palpite'}</button></div>
    </Modal>
  </section>;
}

