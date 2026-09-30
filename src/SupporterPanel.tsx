import { useEffect, useState } from 'react';
import { Box, Zap, Crown, LoaderCircle, QrCode } from 'lucide-react';
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
    const reset = () => setBusy(false);
    window.addEventListener('pageshow', reset);
    return () => window.removeEventListener('pageshow', reset);
  }, []);
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
    <div className="pass-offer-copy">
      <div className="pass-heading"><SupporterEmblem/><div><span className="pass-offer-eyebrow">SEJA UM APOIADOR</span><h2>Evolua mais rápido. Jogue com seu estilo.</h2></div></div>
      <ul className="pass-offer-benefits">
        <li><Zap size={23} aria-hidden="true"/><div><strong>+50% de XP</strong><span>Em todos os ganhos.</span></div></li>
        <li><Box size={23} aria-hidden="true"/><div><strong>7 caixas de personalização</strong><span>Ao assinar e em toda renovação.</span></div></li>
        <li><SupporterEmblem/><div><strong>Emblema de apoiador</strong><span>Seu apoio em destaque no perfil.</span></div></li>
      </ul>
    </div>
    <div className="pass-offer-purchase">
      <p className="pass-offer-price">R$ 4,97<span>/mês</span></p>
    {pass?.active ? <>
      <p className={`pass-current${!paidActive && !prepaidActive ? ' pass-current-free' : ''}`} role="status">{!paidActive && !prepaidActive ? (date ? `Termina em ${date}` : null) : <>{paidActive ? 'Assinatura ativa' : 'Premium por Pix ativo'}{date ? ` · ${paidActive && !pass.cancelAtPeriodEnd ? 'Próxima renovação em' : 'Termina em'} ${date}` : ''}</>}</p>
      {paidActive && <button type="button" className="text-button" disabled={busy} onClick={() => void redirect('pass-portal')}>Gerenciar ou cancelar assinatura</button>}
    </> : pass ? <>
      <button type="button" className="primary-button" disabled={busy} onClick={() => void redirect('pass-checkout')}>{busy ? <LoaderCircle className="spin" size={18}/> : <Crown size={18}/>} Quero ser Apoiador</button>
      <p className="pass-billing-note">R$ 4,97 cobrados ao assinar, com renovação mensal automática. Cancele a qualquer momento.</p>
      {pixEnabled && <><p className="pass-billing-note">Ou pague R$ 4,97 por Pix e tenha Premium por 30 dias, sem renovação automática. O acesso começa após a confirmação do pagamento.</p>
      <button type="button" className="secondary-button" disabled={busy} onClick={() => void redirect('pass-pix')}>{busy ? <LoaderCircle className="spin" size={18}/> : <QrCode size={18}/>} Pagar 30 dias com Pix</button></>}
      {pass.status !== 'none' && <button type="button" className="text-button" disabled={busy} onClick={() => void redirect('pass-portal')}>Gerenciar assinatura anterior</button>}
    </> : <p className="muted text-sm">Carregando assinatura…</p>}
    </div>
    {error && <ErrorNotice message={error} retry={onChanged}/>}
  </section>;
}
