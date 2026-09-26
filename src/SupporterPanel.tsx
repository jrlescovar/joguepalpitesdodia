import { useEffect, useState } from 'react';
import { Check, Clock3, Crown, LoaderCircle, QrCode } from 'lucide-react';
import { call, errorMessage, passRedirect } from './backend';
import { ErrorNotice } from './components';
import type { PassStatus, Profile } from './types';
import './supporter.css';
import SupporterEmblem from './SupporterEmblem';

export default function SupporterPanel({ profile, refreshTick, onChanged }: { profile: Profile; refreshTick: number; onChanged: () => void }) {
  const pixEnabled = import.meta.env.VITE_PIX_ENABLED === 'true';
  const [pass, setPass] = useState<PassStatus | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  useEffect(() => {
    let current = true;
    call<PassStatus>('getPassStatus').then(status => {
      if (current) { setPass(status); }
    }).catch(cause => { if (current) setError(errorMessage(cause)); });
    return () => { current = false; };
  }, [profile.uid, refreshTick]);
  async function redirect(destination: 'pass-checkout'|'pass-portal'|'pass-pix') {
    setBusy(true); setError('');
    try { await passRedirect(destination); } catch (cause) { setError(errorMessage(cause)); setBusy(false); }
  }
  const paidActive = Boolean(pass?.status === 'active' && pass.periodEndsAt && Date.parse(pass.periodEndsAt) > Date.now());
  const prepaidActive = Boolean(pass?.prepaidActive && pass.prepaidEndsAt && Date.parse(pass.prepaidEndsAt) > Date.now());
  const endsAt = paidActive ? pass?.periodEndsAt : prepaidActive ? pass?.prepaidEndsAt : pass?.freeEndsAt;
  const date = endsAt ? new Date(endsAt).toLocaleDateString('pt-BR', { timeZone: 'America/Sao_Paulo' }) : null;
  return <section className="card pass-panel" aria-label="Seja um Apoiador">
    <div className="pass-heading"><SupporterEmblem/><div><h2>Seja um Apoiador</h2><p>R$ 4,97 por mês</p></div></div>
    <ul className="pass-benefits">
      <li><Check size={17} aria-hidden="true"/><span>XP 1,5× em todos os ganhos.</span></li>
      <li><Check size={17} aria-hidden="true"/><span>Emblema de apoiador.</span></li>
      <li><Check size={17} aria-hidden="true"/><span>5x Caixa de Personalização.</span></li>
      <li><Clock3 size={17} aria-hidden="true"/><span>Personalização exclusiva do fundo de perfil <small>— em breve.</small></span></li>
      <li><Clock3 size={17} aria-hidden="true"/><span>Isento de taxa na criação de torneios personalizados <small>— em breve.</small></span></li>
      <li><Clock3 size={17} aria-hidden="true"/><span>Outras novidades em breve.</span></li>
    </ul>
    {pass?.active ? <>
      <p className="pass-current" role="status">{paidActive ? 'Assinatura ativa' : prepaidActive ? 'Premium por Pix ativo' : 'Premium gratuito ativo'}{date ? ` · ${paidActive && !pass.cancelAtPeriodEnd ? 'Próxima renovação em' : 'Termina em'} ${date}` : ''}</p>
      {paidActive && <button type="button" className="text-button" disabled={busy} onClick={() => void redirect('pass-portal')}>Gerenciar ou cancelar assinatura</button>}
    </> : pass ? <>
      <p className="pass-billing-note">A cobrança de R$ 4,97 começa ao assinar e se renova mensalmente. Cancele a assinatura a qualquer momento.</p>
      <button type="button" className="primary-button" disabled={busy} onClick={() => void redirect('pass-checkout')}>{busy ? <LoaderCircle className="spin" size={18}/> : <Crown size={18}/>} Assinar por R$ 4,97/mês</button>
      {pixEnabled && <><p className="pass-billing-note">Ou pague R$ 4,97 por Pix e tenha Premium por 30 dias, sem renovação automática. O acesso começa após a confirmação do pagamento.</p>
      <button type="button" className="secondary-button" disabled={busy} onClick={() => void redirect('pass-pix')}>{busy ? <LoaderCircle className="spin" size={18}/> : <QrCode size={18}/>} Pagar 30 dias com Pix</button></>}
      {pass.status !== 'none' && <button type="button" className="text-button" disabled={busy} onClick={() => void redirect('pass-portal')}>Gerenciar assinatura anterior</button>}
    </> : <p className="muted text-sm">Carregando assinatura…</p>}
    {error && <ErrorNotice message={error}/>}
  </section>;
}
