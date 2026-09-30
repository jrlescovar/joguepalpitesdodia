import { useEffect, useState } from 'react';
import { Bell } from 'lucide-react';
import { call, errorMessage } from './backend';
import { ErrorNotice } from './components';
import './notificationSettings.css';

type Settings = { available: boolean; reminder: boolean; result: boolean };
type Kind = keyof Settings;
const publicKey = 'BCwXAReGx9Q3QMUu_cEJzZw1eL1I6zvwjxK6OHLaediGm5bS3C0S57fE5ihoJerNjOuGPGT5vxS5q3kMKOc4x1E';
const choices: { kind: Kind; label: string; detail: string }[] = [
  { kind: 'available', label: 'Novos palpites', detail: 'O admin avisa quando houver um palpite aberto que você ainda não fez.' },
  { kind: 'reminder', label: 'Perto do prazo', detail: 'Aviso até 30 minutos antes de fechar, se você ainda não palpitou.' },
  { kind: 'result', label: 'Resultados', detail: 'Aviso quando o resultado do palpite sair.' },
];

function applicationServerKey() {
  const padded = (publicKey + '='.repeat((4 - publicKey.length % 4) % 4)).replace(/-/g, '+').replace(/_/g, '/');
  return Uint8Array.from(atob(padded), character => character.charCodeAt(0));
}

const supported = () => 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
const needsHomeScreen = () => /iPad|iPhone|iPod/.test(navigator.userAgent)
  && !window.matchMedia('(display-mode: standalone)').matches
  && !(navigator as Navigator & { standalone?: boolean }).standalone;

export default function NotificationSettings() {
  const [settings, setSettings] = useState<Settings | null>(null);
  const [deviceActive, setDeviceActive] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [retry, setRetry] = useState(0);
  useEffect(() => {
    let active = true;
    void call<Settings>('getMyPushSettings').then(value => { if (active) setSettings(value); })
      .catch(cause => { if (active) setError(errorMessage(cause)); });
    if (supported()) void navigator.serviceWorker.getRegistration('/push-sw.js')
      .then(registration => registration?.pushManager.getSubscription())
      .then(subscription => { if (active) setDeviceActive(Boolean(subscription)); }).catch(() => {});
    return () => { active = false; };
  }, [retry]);

  async function activateDevice() {
    if (needsHomeScreen()) throw new Error('No iPhone, adicione o site à Tela de Início e abra pelo ícone antes de ativar os avisos.');
    if (!supported()) throw new Error('Este navegador não oferece avisos. No iPhone, adicione o site à Tela de Início e abra pelo ícone.');
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') throw new Error('Permita as notificações nas configurações do navegador para receber avisos.');
    const registration = await navigator.serviceWorker.register('/push-sw.js');
    const subscription = await registration.pushManager.getSubscription() ?? await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: applicationServerKey() });
    const keys = subscription.toJSON().keys;
    if (!keys?.p256dh || !keys.auth) throw new Error('Não foi possível ativar os avisos neste aparelho.');
    await call('saveMyPushSubscription', { endpoint: subscription.endpoint, p256dh: keys.p256dh, auth: keys.auth });
    setDeviceActive(true);
  }

  async function toggle(kind: Kind) {
    if (!settings || busy) return;
    setBusy(true); setError('');
    try {
      const next = { ...settings, [kind]: !settings[kind] };
      if (next[kind]) await activateDevice();
      const saved = await call<Settings>('setMyPushSettings', next);
      setSettings(saved);
      if (!saved.available && !saved.reminder && !saved.result && supported()) {
        const registration = await navigator.serviceWorker.getRegistration('/push-sw.js');
        const subscription = await registration?.pushManager.getSubscription();
        if (subscription) { await call('removeMyPushSubscription', { endpoint: subscription.endpoint }); await subscription.unsubscribe(); }
        setDeviceActive(false);
      }
    } catch (cause) { setError(errorMessage(cause)); }
    finally { setBusy(false); }
  }

  async function reconnect() {
    setBusy(true); setError('');
    try { await activateDevice(); }
    catch (cause) { setError(errorMessage(cause)); }
    finally { setBusy(false); }
  }

  return <section className="card profile-notifications" aria-label="Avisos no celular">
    <div className="notification-heading"><Bell size={19}/><div><h2>Avisos no celular</h2><p>Escolha quais avisos quer receber. Todos começam desligados.</p></div></div>
    {error && <ErrorNotice message={error} retry={() => { setError(''); setRetry(value => value + 1); }}/>}
    {!settings && !error && <p className="muted" role="status">Carregando avisos…</p>}
    {settings && <>
      <div className="notification-options">{choices.map(({ kind, label, detail }) => <div className="notification-option" key={kind}><div><strong>{label}</strong><small>{detail}</small></div><button type="button" role="switch" aria-label={label} aria-checked={settings[kind]} className={`toggle ${settings[kind] ? 'on' : ''}`} disabled={busy} onClick={() => void toggle(kind)}><span/></button></div>)}</div>
      {(settings.available || settings.reminder || settings.result) && !deviceActive && <button type="button" className="secondary-button notification-reconnect" disabled={busy} onClick={() => void reconnect()}>Ativar neste aparelho</button>}
      {(!supported() || needsHomeScreen()) && <p className="notification-help">No iPhone, adicione o site à Tela de Início e abra pelo ícone para receber avisos com o navegador fechado.</p>}
    </>}
  </section>;
}
