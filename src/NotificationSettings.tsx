import { useEffect, useState } from 'react';
import { Bell } from 'lucide-react';
import { call, errorMessage } from './backend';
import { ErrorNotice } from './components';
import './notificationSettings.css';
import { activePushRegistration } from './pushRegistration';

type Settings = { available: boolean };
const publicKey = 'BCwXAReGx9Q3QMUu_cEJzZw1eL1I6zvwjxK6OHLaediGm5bS3C0S57fE5ihoJerNjOuGPGT5vxS5q3kMKOc4x1E';
const detail = 'Aviso quando houver novos palpites abertos que você ainda não fez.';

function applicationServerKey() {
  const padded = (publicKey + '='.repeat((4 - publicKey.length % 4) % 4)).replace(/-/g, '+').replace(/_/g, '/');
  return Uint8Array.from(atob(padded), character => character.charCodeAt(0));
}

const supported = () => 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
const needsHomeScreen = () => /iPad|iPhone|iPod/.test(navigator.userAgent)
  && !window.matchMedia('(display-mode: standalone)').matches
  && !(navigator as Navigator & { standalone?: boolean }).standalone;

export default function NotificationSettings({ inDialog = false }: { inDialog?: boolean }) {
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
      .then(subscription => { if (active) setDeviceActive(Boolean(subscription) && Notification.permission === 'granted'); }).catch(() => {});
    return () => { active = false; };
  }, [retry]);

  async function activateDevice() {
    if (needsHomeScreen()) throw new Error('No iPhone, adicione o site à Tela de Início e abra pelo ícone antes de ativar os avisos.');
    if (!supported()) throw new Error('Este navegador não oferece avisos. No iPhone, adicione o site à Tela de Início e abra pelo ícone.');
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') throw new Error('Permita as notificações nas configurações do navegador para receber avisos.');
    const registration = await activePushRegistration(navigator.serviceWorker);
    const subscription = await registration.pushManager.getSubscription() ?? await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: applicationServerKey() });
    const keys = subscription.toJSON().keys;
    if (!keys?.p256dh || !keys.auth) throw new Error('Não foi possível ativar os avisos neste aparelho.');
    await call('saveMyPushSubscription', { endpoint: subscription.endpoint, p256dh: keys.p256dh, auth: keys.auth });
    setDeviceActive(true);
  }

  async function toggle() {
    if (!settings || busy) return;
    setBusy(true); setError('');
    try {
      const next = { available: !settings.available };
      if (next.available) await activateDevice();
      const saved = await call<Settings>('setMyPushSettings', next);
      setSettings(saved);
      if (!saved.available && supported()) {
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

  return <section className={inDialog ? 'notification-settings-dialog' : 'card profile-notifications'} aria-label="Avisos no celular">
    {inDialog ? <p className="notification-intro">Ative o aviso de novos palpites quando quiser recebê-lo neste aparelho.</p> : <div className="notification-heading"><Bell size={19}/><div><h2>Avisos no celular</h2><p>Ative o aviso de novos palpites quando quiser recebê-lo neste aparelho.</p></div></div>}
    {error && <ErrorNotice message={error} retry={() => { setError(''); setRetry(value => value + 1); }}/>}
    {!settings && !error && <p className="muted" role="status">Carregando avisos…</p>}
    {settings && <>
      <div className="notification-options"><div className="notification-option"><div><strong>Novos Palpites</strong><small>{detail}</small></div><button type="button" role="switch" aria-label="Novos Palpites" aria-checked={settings.available} className={`toggle ${settings.available ? 'on' : ''}`} disabled={busy} onClick={() => void toggle()}><span/></button></div></div>
      {settings.available && deviceActive && <p className="notification-help" role="status">Avisos ativados neste aparelho.</p>}
      {settings.available && !deviceActive && <button type="button" className="secondary-button notification-reconnect" disabled={busy} onClick={() => void reconnect()}>{busy ? 'Ativando avisos…' : 'Ativar neste aparelho'}</button>}
      {needsHomeScreen() ? <p className="notification-help">No iPhone, adicione o site à Tela de Início e abra pelo ícone para receber avisos com o navegador fechado.</p> : !supported() && <p className="notification-help">Este navegador não oferece avisos. Tente em um navegador compatível.</p>}
    </>}
  </section>;
}
