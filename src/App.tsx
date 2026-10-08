import { useEffect, useState, lazy, Suspense } from 'react';
import { supabase, login, errorMessage, toAppUser, type AppUser } from './backend';
import LoginScreen from './LoginScreen';
const PlayerApp = lazy(() => import('./PlayerApp'));

export function Brand() { return <a className="brand" href="#inicio" aria-label="Palpitesdodia, início"><img className="brand-mark" src="/favicon.svg?v=brand-3" alt=""/><span>Palpites<span className="brand-light">do</span>dia</span></a>; }
export function LoadingScreen({label='Abrindo seu jogo…'}:{label?:string}) {return <div className="auth-loading" role="status" aria-live="polite"><header className="auth-loading-header"><Brand/></header><main className="auth-loading-main"><strong>{label}</strong><span>Preparando tudo para você.</span><div className="auth-loading-track" aria-hidden="true"><i/></div></main></div>;}
export function App() {
  const [user, setUser] = useState<AppUser|null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  useEffect(() => {
    let active = true;
    supabase.auth.getSession().then(({data,error: authError}) => {
      if (!active) return;
      if (authError) setError(errorMessage(authError));
      setUser(data.session?.user ? toAppUser(data.session.user) : null);
      setLoading(false);
    }).catch(cause => {
      if (active) { setError(errorMessage(cause)); setLoading(false); }
    });
    const {data:{subscription}} = supabase.auth.onAuthStateChange((_event, session) => {
      if (active) { setUser(current => current?.uid === session?.user.id ? current : session?.user ? toAppUser(session.user) : null); setLoading(false); }
    });
    return () => { active = false; subscription.unsubscribe(); };
  }, []);
  async function enter() {setBusy(true);setError('');try {await login();} catch(e) {setError(errorMessage(e));} finally {setBusy(false);} }
  if (loading) return <LoadingScreen label="Conectando sua conta…"/>;
  if (user) return <Suspense fallback={<LoadingScreen/>}><PlayerApp key={user.uid} user={user}/></Suspense>;
  return <LoginScreen onEnter={enter} busy={busy} error={error}/>;
}
export default App;
