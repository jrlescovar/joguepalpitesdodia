import { ArrowRight, Crosshair, LoaderCircle, ShieldCheck, Trophy, Zap } from 'lucide-react';
import './login.css';

export default function LoginScreen({ onEnter, busy, error }: { onEnter: () => void; busy: boolean; error: string }) {
  return <div className="login-page login-redesign">
    <header className="public-header"><a className="brand" href="#conteudo" aria-label="Palpitesdodia, ir para o conteúdo"><img className="brand-mark" src="/favicon.svg?v=brand-3" alt=""/><span>Palpites<span className="brand-light">do</span>dia</span></a><span className="login-version">VERSÃO 1.0</span></header>
    <main id="conteudo" className="login-main login-hero">
      <section className="login-copy">
        <div className="eyebrow"><span/> UM NOVO DESAFIO TODOS OS DIAS</div>
        <h1>Seu palpite<br/><span>vale mais.</span></h1>
        <p className="lead">Escolha seu resultado, acumule greens e suba no ranking. Cada dia é uma nova chance de evoluir.</p>
        <div className="login-actions">
          <button className="google-button" type="button" onClick={onEnter} disabled={busy} aria-busy={busy}>
            <svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24"><path fill="currentColor" d="M21.8 12.2c0-.7-.1-1.5-.2-2.2H12v4.2h5.5a4.7 4.7 0 0 1-2 3.1c-1 .7-2.1 1-3.5 1A6.3 6.3 0 1 1 12 5.7c1.5 0 2.8.5 3.8 1.5l3.1-3.1A10.6 10.6 0 1 0 12 22.6c3 0 5.5-1 7.3-2.8 1.7-1.8 2.5-4.3 2.5-7.6Z"/></svg>
            <span>{busy ? 'Conectando ao Google…' : 'Entrar com Google'}</span>
            {busy ? <LoaderCircle className="spin" size={19}/> : <ArrowRight size={19}/>}
          </button>
          <p className="login-note"><ShieldCheck size={15} aria-hidden="true"/> Acesso seguro, sem criar senha.</p>
          {error && <p className="error" role="alert">{error}</p>}
        </div>
      </section>
    </main>
    <section className="how-it-works" aria-label="O que você encontra no jogo">
      <article><div className="step-icon"><Crosshair/></div><div><small>01 / PALPITE</small><h2>Desafios todos os dias</h2><p>Um desafio diário e até nove extras.</p></div></article>
      <article><div className="step-icon"><Zap/></div><div><small>02 / PROGRESSO</small><h2>Cada green conta</h2><p>Ganhe XP e acompanhe suas conquistas.</p></div></article>
      <article><div className="step-icon"><Trophy/></div><div><small>03 / RANKING</small><h2>Mostre sua evolução</h2><p>Compare seu desempenho com outros jogadores.</p></div></article>
    </section>
    <footer className="public-footer"><span>© 2026 Desenvolvido por Jrlescovar</span></footer>
  </div>;
}
