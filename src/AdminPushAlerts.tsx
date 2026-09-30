import { useState } from 'react';
import { BellRing } from 'lucide-react';
import { call, errorMessage } from './backend';
import { ErrorNotice } from './components';
import type { Prediction } from './types';

export default function AdminPushAlerts({ predictions, selectedDay, today, serverNow }: { predictions: Prediction[]; selectedDay: string; today: string; serverNow: number }) {
  const [sending, setSending] = useState<number | null>(null);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const available = predictions.filter(game => game.dayId === today && game.status === 'open' && game.closesAt.toMillis() > serverNow);
  async function send(slot: number) {
    setSending(slot); setMessage(''); setError('');
    try {
      const result = await call<{ sent: number; users: number; failed: number }>('sendAvailablePush', { dayId: today, slot });
      setMessage(result.sent > 0 ? `Aviso enviado para ${result.users} ${result.users === 1 ? 'jogador' : 'jogadores'} em ${result.sent} ${result.sent === 1 ? 'aparelho' : 'aparelhos'}.` : 'Nenhum novo aviso enviado: não há destinatários pendentes ou eles já foram avisados.');
      if (result.failed > 0) setError(`${result.failed} avisos não puderam ser entregues. Tente novamente mais tarde.`);
    } catch (cause) { setError(errorMessage(cause)); }
    finally { setSending(null); }
  }
  if (selectedDay !== today) return null;
  return <section className="card admin-push-alerts"><h2><BellRing size={18}/> Avisar jogadores</h2><p className="muted text-sm">Envie um aviso sobre um palpite aberto apenas a quem ativou “Novos palpites” e ainda não respondeu.</p>
    {available.length === 0 ? <p className="muted text-sm">Nenhum palpite disponível para avisar agora.</p> : <div className="admin-push-list">{available.map(game => <div key={game.slot}><span>{game.slot === 0 ? 'Palpite do Dia' : `Extra ${game.slot}`}: {game.title}</span><button type="button" className="secondary-button" disabled={sending !== null} onClick={() => void send(game.slot)}>{sending === game.slot ? 'Enviando…' : 'Enviar aviso'}</button></div>)}</div>}
    {message && <p className="success-message" role="status">{message}</p>}{error && <ErrorNotice message={error}/>}
  </section>;
}
