import { useEffect, useState, lazy, Suspense } from 'react';
import { ArrowRight, ChevronRight, Crosshair, LoaderCircle, ShieldCheck, Trophy, Zap } from 'lucide-react';
import { supabase, login, errorMessage, toAppUser, type AppUser } from './backend';
const PlayerApp = lazy(() => import('./PlayerApp'));

export function Brand() { return <a className="brand" href="#inicio" aria-label="Aposta do Dia, início"><span>aposta<span className="brand-light">do</span>dia<span className="brand-dot">.</span></span></a>; }
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
    });
    const {data:{subscription}} = supabase.auth.onAuthStateChange((_event, session) => {
      if (active) { setUser(current => current?.uid === session?.user.id ? current : session?.user ? toAppUser(session.user) : null); setLoading(false); }
    });
    return () => { active = false; subscription.unsubscribe(); };
  }, []);
  async function enter() {setBusy(true);setError('');try {await login();} catch(e) {setError(errorMessage(e));} finally {setBusy(false);} }
  if (loading) return <LoadingScreen label="Conectando sua conta…"/>;
  if (user) return <Suspense fallback={<LoadingScreen/>}><PlayerApp key={user.uid} user={user}/></Suspense>;
  return <div className="login-page"><header className="public-header"><Brand/></header><main id="conteudo" className="login-main"><section className="login-copy"><div className="eyebrow"><span/> UM NOVO DIA. UM NOVO DESAFIO.</div><h1>Seu palpite.<br/>Seu jogo.<br/><span>Sua evolução.</span></h1><p className="lead">Mostre que você entende do jogo.<br/>Acerte o desafio do dia, acumule greens<br className="desktop-break"/> e conquiste seu lugar no ranking.</p><div className="login-actions"><button className="google-button" onClick={enter} disabled={busy} aria-busy={busy}><svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24"><path fill="currentColor" d="M21.8 12.2c0-.7-.1-1.5-.2-2.2H12v4.2h5.5a4.7 4.7 0 0 1-2 3.1c-1 .7-2.1 1-3.5 1A6.3 6.3 0 1 1 12 5.7c1.5 0 2.8.5 3.8 1.5l3.1-3.1A10.6 10.6 0 1 0 12 22.6c3 0 5.5-1 7.3-2.8 1.7-1.8 2.5-4.3 2.5-7.6Z"/></svg><span>{busy?'Conectando ao Google…':'Continuar com Google'}</span>{busy?<LoaderCircle className="spin" size={19}/>:<ArrowRight size={19}/>}</button><p className="login-note"><ShieldCheck size={14}/> Login seguro. Sem senha para lembrar.</p>{error && <p className="error" role="alert">{error}</p>}</div></section></main><section className="how-it-works" aria-label="Como funciona"><article><div className="step-icon"><Crosshair/></div><div><small>01 / ENTRE NO JOGO</small><h2>Um desafio por dia</h2><p>Escolha seu palpite e deixe o jogo acontecer.</p></div><ChevronRight className="step-arrow"/></article><article><div className="step-icon"><Zap/></div><div><small>02 / CONSTRUA SUA JORNADA</small><h2>Cada green, uma evolução</h2><p>Ganhe XP, suba de nível e mantenha a sequência.</p></div><ChevronRight className="step-arrow"/></article><article><div className="step-icon"><Trophy/></div><div><small>03 / VÁ MAIS LONGE</small><h2>Seu lugar entre os melhores</h2><p>Acumule greens e conquiste o ranking global.</p></div></article></section><footer className="public-footer"><span>© 2026 Desenvolvido por Jrlescovar</span></footer></div>;
}
export default App;
