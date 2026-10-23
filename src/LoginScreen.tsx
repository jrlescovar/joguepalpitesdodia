import { ArrowRight, Crosshair, LoaderCircle, ShieldCheck, Swords, Zap } from 'lucide-react';
import './login.css';

export default function LoginScreen({ onEnter, busy, error }: { onEnter: () => void; busy: boolean; error: string }) {
  return <div className="login-page login-redesign">
    <a className="skip-link" href="#conteudo">Pular para o conteúdo</a>
    <header className="public-header"><a className="brand" href="/" aria-label="Palpitesdodia, início"><img className="brand-mark" src="/favicon.svg?v=brand-3" alt=""/><span>Palpites<span className="brand-light">do</span>dia<span className="brand-dot" aria-hidden="true">.</span></span></a><span className="login-version">VERSÃO 1.0</span></header>
    <main id="conteudo" className="login-main login-hero" tabIndex={-1}>
      <section className="login-copy">
        <div className="eyebrow"><span/> FUTEBOL. PALPITES. CONQUISTAS.</div>
        <h1>O jogo começa<br/><span>no seu palpite.</span></h1>
        <p className="lead">Leia o jogo, dispute a Liga e conquiste seu lugar no ranking.</p>
      </section>
      <div className="login-actions">
          <button className="google-button" type="button" onClick={onEnter} disabled={busy} aria-busy={busy}>
            <svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24"><path fill="currentColor" d="M21.8 12.2c0-.7-.1-1.5-.2-2.2H12v4.2h5.5a4.7 4.7 0 0 1-2 3.1c-1 .7-2.1 1-3.5 1A6.3 6.3 0 1 1 12 5.7c1.5 0 2.8.5 3.8 1.5l3.1-3.1A10.6 10.6 0 1 0 12 22.6c3 0 5.5-1 7.3-2.8 1.7-1.8 2.5-4.3 2.5-7.6Z"/></svg>
            <span>{busy ? 'Conectando ao Google…' : 'Entrar com Google'}</span>
            {busy ? <LoaderCircle className="spin" size={19}/> : <ArrowRight size={19}/>}
          </button>
          <p className="login-note"><ShieldCheck size={15} aria-hidden="true"/> Acesso seguro, sem criar senha.</p>
          {error && <p className="error" role="alert">{error}</p>}
      </div>
    </main>
    <section className="how-it-works" aria-label="O que você encontra no jogo">
      <article><div className="step-icon"><Crosshair/></div><div><small>01 / PALPITE</small><h2>Leia o jogo.</h2><p>Um desafio diário e até nove extras.</p></div></article>
      <article><div className="step-icon"><Swords/></div><div><small>02 / DISPUTA</small><h2>Entre na disputa.</h2><p>Jogue a Liga do Dia e participe dos torneios.</p></div></article>
      <article><div className="step-icon"><Zap/></div><div><small>03 / CONQUISTAS</small><h2>Cada green conta.</h2><p>Acerte palpites, ganhe XP e personalize seu perfil.</p></div></article>
    </section>
    <footer className="public-footer"><span>© 2026 Desenvolvido por Jrlescovar</span><nav aria-label="Informações do serviço"><a href="/privacidade">Privacidade</a><a href="/termos">Termos</a><a href="mailto:jrlescovar@gmail.com">Suporte</a></nav></footer>
  </div>;
}
