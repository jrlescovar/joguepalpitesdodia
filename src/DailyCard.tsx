import { useCallback, useEffect, useLayoutEffect, useMemo, useState } from 'react';
import { Check, Clock3, Goal, LockKeyhole, X, Zap } from 'lucide-react';
import { call, errorMessage } from './backend';
import { isDoublePointsDay } from './domain';
import type { Pick, Prediction, Session } from './types';
import { ErrorNotice } from './components';
import './doublePoints.css';
import './dailyChampions.css';
import './dailyStatus.css';
import { teamNameDisplay } from './teamNameDisplay';
import DailyGamesCarousel from './DailyGamesCarousel';
import ChampionsBallIcon from './ChampionsBallIcon';
import LibertadoresIcon from './LibertadoresIcon';
import EuropaLeagueIcon from './EuropaLeagueIcon';
import BrasileiraoIcon from './BrasileiraoIcon';
import PremierLeagueIcon from './PremierLeagueIcon';
import LaLigaIcon from './LaLigaIcon';
import BundesligaIcon from './BundesligaIcon';
import SerieAIcon from './SerieAIcon';
import './dailyBrasileirao.css';
import './dailyPremierLeague.css';
import './dailyLaLiga.css';
import './dailyBundesliga.css';
import './dailySerieA.css';
import './dailyEuropa.css';
import './dailyLibertadores.css';
import { dailyGameLabel as gameLabel, dailyCompetitionLabel, dailyOptionLabel, orderDailyGames } from './dailyGameDisplay';

const gameKey = (game: Prediction) => `${game.dayId}-${game.slot}`;

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
  const title = teamNameDisplay(prediction.title);
  const expired = prediction.closesAt.toMillis() <= now || prediction.status !== 'open';
  const doublePoints = isDoublePointsDay(prediction.dayId);
  const showXp = !expired && pick === null;
  const competition=dailyCompetitionLabel(prediction.description);
  const brasileirao=competition==='Brasileirão';
  const premier=competition==='Premier League';
  const laLiga=competition==='La Liga';
  const bundesliga=competition==='Bundesliga';
  const serieA=competition==='Serie A';
  const libertadores=/^(?:(?:Copa|CONMEBOL)\s+)?Libertadores$/iu.test(competition);
  const europa=/^(?:UEFA\s+)?(?:Europa\s+League|Liga\s+Europa)$/iu.test(competition);
  return <section className={`card daily-card${doublePoints ? ' daily-card-double-points' : ''}`} data-competition-theme={competition==='Liga dos Campeões'?'champions':libertadores?'libertadores':europa?'europa':brasileirao?'brasileirao':premier?'premier-league':laLiga?'la-liga':bundesliga?'bundesliga':serieA?'serie-a':undefined}><div className="daily-header"><span>{competition==='Liga dos Campeões'?<ChampionsBallIcon/>:libertadores?<LibertadoresIcon/>:europa?<EuropaLeagueIcon/>:brasileirao?<BrasileiraoIcon/>:premier?<PremierLeagueIcon/>:laLiga?<LaLigaIcon/>:bundesliga?<BundesligaIcon/>:serieA?<SerieAIcon/>:<Goal size={18}/>} {gameLabel(prediction).toUpperCase()}</span>{(doublePoints || showXp || expired) && <div className="daily-rewards">{doublePoints && <span className="double-points-pill" aria-label="Evento: dobro de pontos">X2 pts</span>}{showXp && <span className={`xp-pill${supporterActive ? ' xp-pill-premium' : ''}`}><Zap size={14} aria-hidden="true"/> +{supporterActive ? 10 : 5} XP</span>}{expired&&<span className="daily-header-status"><Clock3 size={12} aria-hidden="true"/>{prediction.status==='settled'?'ENCERRADO':'EM JOGO'}</span>}</div>}</div>
    {pick === undefined ? <DailySkeleton /> : <div className="prediction-content"><h2 className={title.length > 65 ? 'game-title-very-long' : title.length > 32 ? 'game-title-long' : prediction.slot === 8 ? 'game-title-compact' : undefined}>{gameTitle(title)}</h2><p className="muted text-sm">{competition}</p>
      {!expired && <><span className="deadline"><Clock3 size={14} />PALPITES ENCERRAM EM</span><Countdown until={prediction.closesAt.toMillis()} offset={offset} active={countdownActive} /></>}
      <fieldset disabled={Boolean(pick) || expired || busy}><legend className="field-label">{pick ? 'Seu palpite está confirmado' : 'Qual é o seu palpite?'}</legend>
        <div className={`pick-options options-${prediction.options.length}`}>{prediction.options.map(option => <label key={option.id} className={`${(pick?.optionId || selected) === option.id ? 'selected' : ''} ${prediction.winningOptionId === option.id ? 'winner' : ''}`}>
          <input type="radio" name={`pick-${gameKey(prediction)}-${instanceId}`} value={option.id} checked={(pick?.optionId || selected) === option.id} onChange={() => onSelect(option.id)} onClick={() => { if (!pick && selected === option.id) onSelect(''); }} />
          <span className="option-copy"><span>{dailyOptionLabel(prediction, option)}</span>{typeof option.rankPoints === 'number' && <small>+{option.rankPoints} pts</small>}</span>{prediction.winningOptionId !== option.id && <span className="radio-indicator" />}
        </label>)}</div>
      </fieldset>
      {pick ? (pick.status !== 'pending' || expired ? <div className={`pick-result ${pick.status}`} role="status">{pick.status === 'green' ? <Check /> : pick.status === 'red' ? <X /> : <LockKeyhole />}
        <span>{pick.status === 'green' ? `Deu green! +${supporterActive ? 50 : 25} XP para você.` : pick.status === 'red' ? 'Deu red. O próximo palpite é uma nova chance.' : 'Aguardando o resultado.'}</span></div> : null)
        : !expired ? (selected ? <button className="primary-button w-full mt-5" disabled={busy} onClick={onSubmit}>{busy ? 'Confirmando…' : 'Confirmar meu palpite'} <Check size={18} /></button> : null)
          : <div className="pick-result pending" role="status"><LockKeyhole /><span>{prediction.status === 'settled' ? 'Este palpite foi encerrado.' : 'Em jogo. O prazo para novos palpites terminou.'}</span></div>}
    </div>}
  </section>;
}

export default function DailyCard({ uid, session, refreshTick, supporterActive, onChanged }: { uid: string; session: Session; refreshTick: number; supporterActive: boolean; onChanged?: () => void }) {
  const [desktop, setDesktop] = useState(() => window.matchMedia('(min-width: 1024px)').matches);
  const [games, setGames] = useState<Prediction[] | undefined>();
  const [picks, setPicks] = useState<Record<string, Pick | null | undefined>>({});
  const [selected, setSelected] = useState<Record<string, string>>({});
  const clearPendingSelections = useCallback(() => setSelected(previous => Object.keys(previous).length ? {} : previous), []);
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
  const displayGames=orderDailyGames(games);
  const cards=displayGames.length === 1 ? renderGame(displayGames[0], 'single', true)
    : <DailyGamesCarousel key={desktop?'desktop':'mobile'} games={displayGames} now={Date.now() + clockOffset} desktop={desktop} renderGame={renderGame} onPageChange={clearPendingSelections} />;
  return <>{cards}{waitingForResults&&<p className="upcoming-predictions-notice" role="status">Palpites para o dia seguinte estará disponível em instantes!</p>}</>;
}
