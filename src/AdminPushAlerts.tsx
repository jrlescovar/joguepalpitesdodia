import { useState } from 'react';
import { BellRing } from 'lucide-react';
import { call, errorMessage } from './backend';
import { ErrorNotice } from './components';

export default function AdminPushAlerts() {
  const [sending, setSending] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  async function send() {
    setSending(true); setMessage(''); setError('');
    try {
      const result = await call<{ sent: number; users: number; failed: number }>('sendAvailablePush');
      setMessage(result.sent > 0
        ? `Aviso enviado para ${result.users} ${result.users === 1 ? 'jogador' : 'jogadores'} em ${result.sent} ${result.sent === 1 ? 'aparelho' : 'aparelhos'}.`
        : 'Nenhum novo aviso enviado: não há palpites abertos pendentes para jogadores com avisos ativados, ou eles já foram avisados.');
      if (result.failed > 0) setError(`${result.failed} avisos não puderam ser entregues. Tente novamente mais tarde.`);
    } catch (cause) { setError(errorMessage(cause)); }
    finally { setSending(false); }
  }

  return <section className="card admin-push-alerts">
    <h2><BellRing size={18}/> Avisar jogadores</h2>
    <p className="muted text-sm">Envie um aviso a quem ativou “Novos Palpites” e ainda não fez algum palpite aberto de hoje.</p>
    <button type="button" className="secondary-button" disabled={sending} onClick={() => void send()}>{sending ? 'Enviando…' : 'Enviar aviso'}</button>
    {message && <p className="success-message" role="status">{message}</p>}
    {error && <ErrorNotice message={error}/>}
  </section>;
}
