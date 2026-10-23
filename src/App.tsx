import { useEffect, useState, lazy, Suspense } from 'react';
import type { AppUser } from './backend';
import { authStorageKey, needsAuthRestore } from './authBootstrap';
import LoginScreen from './LoginScreen';
const PlayerApp = lazy(() => import('./PlayerApp'));
const storageKey = authStorageKey(import.meta.env.VITE_SUPABASE_URL || '');
function shouldRestoreSession() {
  try { return needsAuthRestore(new URL(location.href),localStorage,storageKey); }
  catch { return true; }
}

export function Brand() { return <a className="brand" href="#inicio" aria-label="Palpitesdodia, início"><img className="brand-mark" src="/favicon.svg?v=brand-3" alt=""/><span>Palpites<span className="brand-light">do</span>dia<span className="brand-dot" aria-hidden="true">.</span></span></a>; }
export function LoadingScreen({label='Abrindo seu jogo…'}:{label?:string}) {return <div className="auth-loading" role="status" aria-live="polite"><header className="auth-loading-header"><Brand/></header><main className="auth-loading-main"><strong>{label}</strong><span>Preparando tudo para você.</span><div className="auth-loading-track" aria-hidden="true"><i/></div></main></div>;}
export function App() {
  const [user, setUser] = useState<AppUser|null>(null);
  const [loading, setLoading] = useState(shouldRestoreSession);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  useEffect(() => {
    let active = true;
    let subscription: { unsubscribe(): void } | undefined;
    let attached = false;
    const attach = async () => {
      if (attached) return;
      attached = true;
      try {
        const {supabase, errorMessage, toAppUser} = await import('./backend');
        if (!active) return;
        subscription = supabase.auth.onAuthStateChange((_event, session) => {
          if (active) { setUser(current => current?.uid === session?.user.id ? current : session?.user ? toAppUser(session.user) : null); setLoading(false); }
        }).data.subscription;
        const {data,error: authError} = await supabase.auth.getSession();
        if (!active) return;
        if (authError) setError(errorMessage(authError));
        setUser(data.session?.user ? toAppUser(data.session.user) : null);
        setLoading(false);
      } catch {
        if (active) { setError('Não foi possível recuperar sua sessão. Tente entrar novamente.'); setLoading(false); }
      }
    };
    if (shouldRestoreSession()) void attach();
    else setLoading(false);
    const restoreFromAnotherTab = (event: StorageEvent) => {
      if (event.key === storageKey && event.newValue) void attach();
    };
    window.addEventListener('storage', restoreFromAnotherTab);
    return () => { active = false; subscription?.unsubscribe(); window.removeEventListener('storage', restoreFromAnotherTab); };
  }, []);
  async function enter() {
    setBusy(true);setError('');
    let describe = (_cause: unknown) => 'Não foi possível conectar ao Google. Tente novamente.';
    try {const {login,errorMessage}=await import('./backend');describe=errorMessage;await login();}
    catch(cause) {setError(describe(cause));}
    finally {setBusy(false);}
  }
  if (loading) return <LoadingScreen label="Conectando sua conta…"/>;
  if (user) return <Suspense fallback={<LoadingScreen/>}><PlayerApp key={user.uid} user={user}/></Suspense>;
  return <LoginScreen onEnter={enter} busy={busy} error={error}/>;
}
export default App;
