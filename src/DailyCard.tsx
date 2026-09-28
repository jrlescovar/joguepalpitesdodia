import { useEffect, useLayoutEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Check, ChevronLeft, ChevronRight, Clock3, Goal, LockKeyhole, X, Zap } from 'lucide-react';
import { call, errorMessage } from './backend';
import { firstPlayableGameIndex } from './domain';
import type { Pick, Prediction, Session } from './types';
import { ErrorNotice } from './components';

const gameKey = (game: Prediction) => `${game.dayId}-${game.slot}`;
const gameLabel = (game: Prediction) => game.slot === 0 ? 'Palpites do Dia' : `Palpite Extra ${game.slot}`;

function gameTitle(title: string) {
  const questionEnd = title.indexOf('?');
  const rest = title.slice(questionEnd + 1).trimStart();
  return questionEnd >= 0 && rest ? <>{title.slice(0, questionEnd + 1)}<br />{' '}{rest}</> : title;
}

function Countdown({ until, offset, active }: { until: number; offset: number; active: boolean }) {
  const [now, setNow] = useState(() => Date.now() + offset);
  useLayoutEffect(() => {
    if (!active) return;
    const update = () => setNow(Date.now() + offset);
    const onVisible = () => { if (document.visibilityState === 'visible') update(); };
    update();
    const timer = window.setInterval(onVisible, 1000);
    document.addEventListener('visibilitychange', onVisible);
    return () => { clearInterval(timer); document.removeEventListener('visibilitychange', onVisible); };
  }, [active, offset]);
  const remaining = Math.max(0, until - now);
  const days = Math.floor(remaining / 86400000);
  const hours = Math.floor(remaining % 86400000 / 3600000);
  const minutes = Math.floor(remaining % 3600000 / 60000);
  const seconds = Math.floor(remaining % 60000 / 1000);
  return <div className="countdown" role="timer" aria-label={`${days} dias, ${hours} horas, ${minutes} minutos e ${seconds} segundos`}>
    <span><strong>{String(days).padStart(2, '0')}</strong><small>Dias</small></span>
    <span><strong>{String(hours).padStart(2, '0')}</strong><small>Horas</small></span>
    <span><strong>{String(minutes).padStart(2, '0')}</strong><small>Min</small></span>
    <span><strong>{String(seconds).padStart(2, '0')}</strong><small>Seg</small></span>
  </div>;
}

function DailySkeleton() {
  return <div className="daily-skeleton" role="status" aria-label="Buscando o palpite">
    <div className="skeleton-line skeleton-title" aria-hidden="true" />
    <div className="skeleton-line skeleton-description" aria-hidden="true" />
    <div className="skeleton-countdown" aria-hidden="true"><i /><i /><i /><i /></div>
    <div className="skeleton-options" aria-hidden="true"><i /><i /><i /></div>
  </div>;
}

function GameCard({ prediction, instanceId, pick, selected, now, offset, countdownActive, supporterActive, busy, onSelect, onSubmit }: {
  prediction: Prediction;
  instanceId: string;
  pick: Pick | null | undefined;
  selected: string;
  now: number;
  offset: number;
  countdownActive: boolean;
  supporterActive: boolean;
  busy: boolean;
  onSelect: (optionId: string) => void;
  onSubmit: () => void;
}) {
  const expired = prediction.closesAt.toMillis() <= now || prediction.status !== 'open';
  return <section className="card daily-card"><div className="daily-header"><span><Goal size={18} /> {gameLabel(prediction).toUpperCase()}</span>{(supporterActive || (!expired && !pick)) && <span className={`xp-pill${supporterActive ? ' xp-pill-premium' : ''}`}><Zap size={14} aria-hidden="true"/> +{supporterActive ? 8 : 5} XP</span>}</div>
    {pick === undefined ? <DailySkeleton /> : <div className="prediction-content"><h2 className={prediction.title.length > 65 ? 'game-title-very-long' : prediction.title.length > 32 ? 'game-title-long' : undefined}>{gameTitle(prediction.title)}</h2><p className="muted text-sm whitespace-pre-line">{prediction.description}</p>
      <span className={`deadline ${expired ? 'in-play' : ''}`}><Clock3 size={14} />{prediction.status === 'settled' ? 'RESULTADO CONFIRMADO' : expired ? 'EM JOGO' : 'PALPITES ENCERRAM EM'}</span>
      {!expired && <Countdown until={prediction.closesAt.toMillis()} offset={offset} active={countdownActive} />}
      <fieldset disabled={Boolean(pick) || expired || busy}><legend className="field-label">{pick ? 'Seu palpite está confirmado' : 'Qual é o seu palpite?'}</legend>
        <div className={`pick-options options-${prediction.options.length}`}>{prediction.options.map(option => <label key={option.id} className={`${(pick?.optionId || selected) === option.id ? 'selected' : ''} ${prediction.winningOptionId === option.id ? 'winner' : ''}`}>
          <input type="radio" name={`pick-${gameKey(prediction)}-${instanceId}`} value={option.id} checked={(pick?.optionId || selected) === option.id} onChange={() => onSelect(option.id)} />
          <span className="option-copy"><span>{option.label.toLocaleLowerCase('pt-BR') === 'empate' ? 'X' : option.label}</span>{typeof option.rankPoints === 'number' && <small>+{option.rankPoints} pts</small>}</span>{prediction.winningOptionId !== option.id && <span className="radio-indicator" />}
        </label>)}</div>
      </fieldset>
      {pick ? (pick.status !== 'pending' || expired ? <div className={`pick-result ${pick.status}`} role="status">{pick.status === 'green' ? <Check /> : pick.status === 'red' ? <X /> : <LockKeyhole />}
        <span>{pick.status === 'green' ? `Deu green! +${supporterActive ? 38 : 25} XP para você.` : pick.status === 'red' ? 'Deu red. O próximo palpite é uma nova chance.' : 'Aguardando o resultado.'}</span></div> : null)
        : !expired ? <button className="primary-button w-full mt-5" disabled={!selected || busy} onClick={onSubmit}>{busy ? 'Confirmando…' : 'Confirmar meu palpite'} <Check size={18} /></button>
          : <div className="pick-result pending" role="status"><LockKeyhole /><span>{prediction.status === 'settled' ? 'Este palpite foi encerrado.' : 'Em jogo. O prazo para novos palpites terminou.'}</span></div>}
    </div>}
  </section>;
}

function MobileGames({ games, now, renderGame }: { games: Prediction[]; now: number; renderGame: (game: Prediction, instanceId: string, countdownActive: boolean) => ReactNode }) {
  const rail = useRef<HTMLDivElement>(null);
  const slides = useRef<(HTMLDivElement | null)[]>([]);
  const touchStart = useRef<{ x: number; y: number; index: number } | null>(null);
  const initialIndex = useRef(firstPlayableGameIndex(games, now));
  const positioned = useRef(false);
  const [active, setActive] = useState(initialIndex.current);

  useLayoutEffect(() => {
    const container = rail.current;
    if (!container) return;
    if (!positioned.current) {
      const target = slides.current[initialIndex.current];
      if (target) {
        container.scrollLeft += target.getBoundingClientRect().left - container.getBoundingClientRect().left;
        positioned.current = true;
      }
    }
    let frame = 0;
    const fitActiveCard = () => {
      const left = container.getBoundingClientRect().left;
      let nearest = 0;
      let distance = Infinity;
      slides.current.forEach((slide, index) => {
        if (!slide) return;
        const delta = Math.abs(slide.getBoundingClientRect().left - left);
        if (delta < distance) { nearest = index; distance = delta; }
      });
      setActive(nearest);
      // Leave a few pixels below the active card so the rail's vertical clip
      // does not cut off its rounded bottom border on mobile screens.
      const height = `${Math.ceil(slides.current[nearest]?.getBoundingClientRect().height ?? 0) + 3}px`;
      if (container.style.height !== height) container.style.height = height;
    };
    const scheduleFit = () => {
      if (frame) return;
      frame = requestAnimationFrame(() => { frame = 0; fitActiveCard(); });
    };
    const observer = new ResizeObserver(scheduleFit);
    slides.current.forEach(slide => { if (slide) observer.observe(slide); });
    container.addEventListener('scroll', scheduleFit, { passive: true });
    fitActiveCard();
    return () => { observer.disconnect(); container.removeEventListener('scroll', scheduleFit); cancelAnimationFrame(frame); };
  }, [games.length]);

  const goTo = (index: number) => {
    const container = rail.current;
    const slide = slides.current[index];
    if (!container || !slide) return;
    const left = container.scrollLeft + slide.getBoundingClientRect().left - container.getBoundingClientRect().left;
    container.scrollTo({ left, behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth' });
  };
  const startSwipe = (event: React.TouchEvent<HTMLDivElement>) => {
    if (event.touches.length !== 1) { touchStart.current = null; return; }
    touchStart.current = { x: event.touches[0].clientX, y: event.touches[0].clientY, index: active };
  };
  const finishSwipe = (event: React.TouchEvent<HTMLDivElement>) => {
    const start = touchStart.current;
    touchStart.current = null;
    if (!start || event.changedTouches.length !== 1) return;
    const dx = event.changedTouches[0].clientX - start.x;
    const dy = event.changedTouches[0].clientY - start.y;
    if (Math.abs(dx) < 45 || Math.abs(dx) <= Math.abs(dy) * 1.25) return;
    event.preventDefault();
    goTo(Math.max(0, Math.min(games.length - 1, start.index + (dx < 0 ? 1 : -1))));
  };
  return <div className="mobile-games" role="region" aria-label="Palpites do dia; deslize para os lados para trocar de palpite" tabIndex={0}>
    <div className="mobile-games-rail" ref={rail} onTouchStart={startSwipe} onTouchEnd={finishSwipe} onTouchCancel={() => { touchStart.current = null; }}>
      {games.map((game, index) => <div className="daily-slide" ref={element => { slides.current[index] = element; }} key={gameKey(game)}>{renderGame(game, 'mobile', active === index)}</div>)}
    </div>
    <div className="mobile-games-indicator" aria-label="Selecionar palpite">
      {games.map((game, index) => <button type="button" key={gameKey(game)} className={active === index ? 'active' : ''} aria-label={gameLabel(game)} aria-current={active === index ? 'true' : undefined} onClick={() => goTo(index)} />)}
    </div>
  </div>;
}

function DesktopGames({ games, now, renderGame }: { games: Prediction[]; now: number; renderGame: (game: Prediction, instanceId: string, countdownActive: boolean) => ReactNode }) {
  const rail = useRef<HTMLDivElement>(null);
  const pages = useRef<(HTMLDivElement | null)[]>([]);
  const dragStart = useRef<{ x: number; page: number } | null>(null);
  const initialPage = useRef(Math.floor(firstPlayableGameIndex(games, now) / 2));
  const [active, setActive] = useState(initialPage.current);
  const pageCount = Math.ceil(games.length / 2);
  useLayoutEffect(() => {
    const container = rail.current;
    if (!container) return;
    const initial = pages.current[initialPage.current];
    if (initial) container.scrollLeft = initial.offsetLeft - (pages.current[0]?.offsetLeft ?? 0);
    let frame = 0;
    const update = () => {
      const left = container.getBoundingClientRect().left;
      let nearest = 0;
      let distance = Infinity;
      pages.current.forEach((page, index) => {
        if (!page) return;
        const delta = Math.abs(page.getBoundingClientRect().left - left);
        if (delta < distance) { nearest = index; distance = delta; }
      });
      setActive(nearest);
      container.style.height = `${Math.ceil(pages.current[nearest]?.getBoundingClientRect().height ?? 0) + 3}px`;
    };
    const schedule = () => { cancelAnimationFrame(frame); frame = requestAnimationFrame(update); };
    const observer = new ResizeObserver(schedule);
    pages.current.forEach(page => { if (page) observer.observe(page); });
    container.addEventListener('scroll', schedule, { passive: true });
    update();
    return () => { observer.disconnect(); container.removeEventListener('scroll', schedule); cancelAnimationFrame(frame); };
  }, [games.length]);
  const goTo = (page: number) => {
    const container = rail.current;
    const target = pages.current[page];
    if (!container || !target) return;
    container.scrollTo({ left: target.offsetLeft - (pages.current[0]?.offsetLeft ?? 0), behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth' });
  };
  return <div className="desktop-games-carousel" role="region" aria-label="Palpites do dia; dois por vez">
    <div className="desktop-games-rail" ref={rail} onPointerDown={event => { if (event.pointerType === 'mouse') dragStart.current = { x: event.clientX, page: active }; }} onPointerUp={event => {
      const start = dragStart.current;
      dragStart.current = null;
      if (!start || event.pointerType !== 'mouse' || Math.abs(event.clientX - start.x) < 45) return;
      goTo(Math.max(0, Math.min(pageCount - 1, start.page + (event.clientX < start.x ? 1 : -1))));
    }} onPointerCancel={() => { dragStart.current = null; }}>
      {Array.from({ length: pageCount }, (_, page) => <div className="desktop-games-page daily-games desktop-games" ref={element => { pages.current[page] = element; }} key={page}>
        {games.slice(page * 2, page * 2 + 2).map(game => <div className="daily-slide" key={gameKey(game)}>{renderGame(game, `desktop-${page}`, page === active)}</div>)}
      </div>)}
    </div>
    <div className="desktop-games-controls"><button type="button" aria-label="Dois palpites anteriores" disabled={active === 0} onClick={() => goTo(active - 1)}><ChevronLeft size={20}/></button><span>{active + 1} / {pageCount}</span><button type="button" aria-label="Próximos dois palpites" disabled={active === pageCount - 1} onClick={() => goTo(active + 1)}><ChevronRight size={20}/></button></div>
  </div>;
}
export default function DailyCard({ uid, session, refreshTick, supporterActive, onChanged }: { uid: string; session: Session; refreshTick: number; supporterActive: boolean; onChanged?: () => void }) {
  const [desktop, setDesktop] = useState(() => window.matchMedia('(min-width: 1024px)').matches);
  const [games, setGames] = useState<Prediction[] | undefined>();
  const [picks, setPicks] = useState<Record<string, Pick | null | undefined>>({});
  const [selected, setSelected] = useState<Record<string, string>>({});
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const [now, setNow] = useState(session.serverTime);
  const clockOffset = useMemo(() => session.serverTime - Date.now(), [session.serverTime]);
  useEffect(() => {
    const media = window.matchMedia('(min-width: 1024px)');
    const update = () => setDesktop(media.matches);
    media.addEventListener('change', update);
    return () => media.removeEventListener('change', update);
  }, []);
  useEffect(() => {
    let active = true;
    setError('');
    call<Prediction[]>('getCurrentPredictions').then(async values => {
      const dayId = values[0]?.dayId;
      const currentPicks = dayId ? await call<Pick[]>('getPicksForDay', { dayId }) : [];
      const loaded: Record<string, Pick | null> = Object.fromEntries(values.map(game => [gameKey(game), null]));
      currentPicks.forEach(pick => { loaded[`${pick.dayId}-${pick.slot}`] = pick; });
      if (active) { setPicks(loaded); setGames(values); }
    }).catch(cause => { if (active) setError(errorMessage(cause)); });
    return () => { active = false; };
  }, [uid, reload, refreshTick]);
  useEffect(() => {
    const update = () => setNow(Date.now() + clockOffset);
    update();
    const current = Date.now() + clockOffset;
    const timers = games?.filter(game => game.status === 'open' && game.closesAt.toMillis() > current)
      .map(game => window.setTimeout(update, Math.min(game.closesAt.toMillis() - current + 100, 2147483647))) ?? [];
    const onVisible = () => { if (document.visibilityState === 'visible') update(); };
    document.addEventListener('visibilitychange', onVisible);
    return () => { timers.forEach(clearTimeout); document.removeEventListener('visibilitychange', onVisible); };
  }, [clockOffset, games]);
  async function submit(game: Prediction) {
    const key = gameKey(game);
    const optionId = selected[key];
    if (!optionId || picks[key] || busyKey) return;
    setBusyKey(key);
    setError('');
    try {
      await call('submitPick', { dayId: game.dayId, slot: game.slot, optionId });
      setPicks(previous => ({ ...previous, [key]: { dayId: game.dayId, slot: game.slot, optionId, status: 'pending' } }));
      onChanged?.();
    } catch (cause) { setError(errorMessage(cause)); }
    finally { setBusyKey(null); }
  }
  if (error) return <ErrorNotice message={error} retry={() => setReload(value => value + 1)} />;
  if (!games) return <section className="card daily-card"><DailySkeleton /></section>;
  if (games.length === 0) return <section className="card daily-card"><div className="daily-header"><span><Goal size={18} /> PALPITES DO DIA</span></div><div className="daily-empty"><div className="empty-icon"><Clock3 size={33} /></div><span className="eyebrow">PRÓXIMO PALPITE</span><h2>Aguardando o próximo desafio</h2><p>Assim que o administrador publicar, o desafio aparecerá aqui.</p></div></section>;
  const renderGame = (game: Prediction, instanceId: string, countdownActive: boolean) => <GameCard prediction={game} instanceId={instanceId} pick={picks[gameKey(game)]} selected={selected[gameKey(game)] || ''} now={now} offset={clockOffset} countdownActive={countdownActive} supporterActive={supporterActive} busy={busyKey === gameKey(game)} onSelect={optionId => setSelected(previous => ({ ...previous, [gameKey(game)]: optionId }))} onSubmit={() => void submit(game)} />;
  const todaysGames=games.filter(game=>game.dayId===session.dayId);
  const waitingForResults=todaysGames.length>0
    && todaysGames.every(game=>game.status!=='open'||game.closesAt.toMillis()<=now)
    && todaysGames.some(game=>game.status!=='settled');
  const cards=games.length === 1 ? renderGame(games[0], 'single', true) : desktop
    ? <DesktopGames games={games} now={Date.now() + clockOffset} renderGame={renderGame} />
    : <MobileGames games={games} now={Date.now() + clockOffset} renderGame={renderGame} />;
  return <>{cards}{waitingForResults&&<p className="upcoming-predictions-notice" role="status">Palpites para o dia seguinte está liberado em instantes</p>}</>;
}
