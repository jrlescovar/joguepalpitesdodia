import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ArrowLeft, ArrowRight, CalendarDays, Check, CircleHelp, Clock3, Crosshair, ListChecks, LoaderCircle, QrCode, RefreshCw, Trophy, Users, Wallet } from 'lucide-react';
import { call, errorMessage, invalidateReads, passRedirect } from './backend';
import { Avatar, ErrorNotice, Loading, Modal } from './components';
import UsernameText from './UsernameText';
import ProfileOverview from './ProfileOverview';
import {useOwnProfileRedirect,usePublicProfileNavigation} from './usePublicProfileNavigation';
import TournamentSelector from './TournamentSelector';
import TournamentPredictions from './TournamentPredictions';
import type { FinishingTournamentState, TournamentPlayer } from './finishingTournamentTypes';
import { tournamentTime } from './finishingTournamentTypes';
import type { PublicProfile } from './types';
import './finishingTournament.css';

export type { FinishingTournamentState, TournamentPlayer } from './finishingTournamentTypes';
const money = (cents: number) => (cents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
const dateLabel = (value: string) => new Date(value).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', timeZone: 'America/Sao_Paulo' });

function TournamentCountdown({ until, offset, onReached }: { until: number; offset: number; onReached: () => void }) {
  const [remaining, setRemaining] = useState(() => Math.max(0, until - Date.now() - offset));
  const reached = useRef(false);
  useEffect(() => {
    reached.current = false;
    const update = () => {
      if (document.visibilityState !== 'visible') return;
      const next = Math.max(0, until - Date.now() - offset);
      setRemaining(next);
      if (next === 0 && !reached.current) { reached.current = true; onReached(); }
    };
    update();
    const timer = window.setInterval(update, 1000);
    document.addEventListener('visibilitychange', update);
    return () => { clearInterval(timer); document.removeEventListener('visibilitychange', update); };
  }, [until, offset, onReached]);
  const seconds = Math.ceil(remaining / 1000);
  const values = [Math.floor(seconds / 86400), Math.floor(seconds / 3600) % 24, Math.floor(seconds / 60) % 60, seconds % 60];
  return <div className="tournament-countdown" role="timer" aria-label="Contagem regressiva do torneio" aria-live="off">
    {values.map((value, index) => <div key={index}><strong>{String(value).padStart(2, '0')}</strong><span>{['DIAS', 'HORAS', 'MIN', 'SEG'][index]}</span></div>)}
  </div>;
}

function TournamentRankingRow({ player, ownUid, onOpen, settledCount }: { player: TournamentPlayer; settledCount: number; ownUid: string; onOpen: (player: TournamentPlayer) => void }) {
  return <li className={player.uid === ownUid ? 'is-me' : ''}><button type="button" onClick={() => onOpen(player)} aria-label={`Abrir perfil de ${player.username}, posição ${player.position}, ${player.correctAnswers} acertos em ${settledCount} resultados confirmados`}>
    <span className={`global-rank-position${player.position===1?' tournament-position-first':''}${player.position>=10&&player.position<=99?' tournament-position-two-digits':''}`}>#{player.position}</span>
    <Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl} borderStyle={player.passBorderStyle}/>
    <span className="global-rank-player"><strong className={`pass-name-${player.passNameStyle ?? 'none'}`}><UsernameText name={player.username} font={player.usernameFont}/></strong></span>
    <strong className="tournament-hits">{player.correctAnswers}<small> / {settledCount}</small></strong>
  </button></li>;
}

type TournamentViewProps = { ownUid: string; refreshTick: number; today: string; lastClosedPrediction: string | null; overviewOnly?: boolean; initialTournamentId?: string; initialData?: FinishingTournamentState; onOpenDetails?: (data: FinishingTournamentState) => void };

export default function FinishingTournament({ ownUid, refreshTick, today, lastClosedPrediction, overviewOnly = false, initialTournamentId, initialData, onOpenDetails }: TournamentViewProps) {
  const [tournamentId, setTournamentId] = useState<string | null>(initialTournamentId ?? null);
  const [data, setData] = useState<FinishingTournamentState | null>(initialData ?? null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const [desktop, setDesktop] = useState(() => window.matchMedia('(min-width: 1024px)').matches);
  useEffect(() => {
    const media = window.matchMedia('(min-width: 1024px)');
    const update = () => setDesktop(media.matches);
    media.addEventListener('change', update);
    return () => media.removeEventListener('change', update);
  }, []);
  const [details, setDetails] = useState(false);
  const [rules, setRules] = useState(false);
  const [busy, setBusy] = useState(false);
  const [selected, setSelected] = useState<PublicProfile | null>(null);
  const tournamentCache = useMemo(() => new Map<string, { data: FinishingTournamentState; receivedAt: number }>(), [ownUid, refreshTick, reload]);
  const readContext = useRef({ ownUid, refreshTick });
  const redirectOwnProfile=useOwnProfileRedirect();
  const {openPublicProfile,cancelProfileOpen,profileOpenNotice}=usePublicProfileNavigation(setSelected);
  const retry = useCallback(() => { invalidateReads(); setReload(value => value + 1); }, []);
  useEffect(() => {
    let active = true;
    if (readContext.current.ownUid !== ownUid || readContext.current.refreshTick !== refreshTick) {
      invalidateReads(); readContext.current = { ownUid, refreshTick };
    }
    setLoading(true); setError('');
    call<FinishingTournamentState | null>('getFinishingTournament', { tournamentId })
      .then(result => { if (active) { if (result) tournamentCache.set(result.id, { data: result, receivedAt: Date.now() }); setData(result); } })
      .catch(cause => { if (active) setError(errorMessage(cause)); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [ownUid, refreshTick, reload, tournamentId, tournamentCache]);
  useEffect(() => {
    if (!data || overviewOnly) return;
    let active = true;
    for (const tournament of data.availableTournaments ?? []) {
      const cached = tournamentCache.get(tournament.id);
      if (cached && Date.now() - cached.receivedAt < 30000) continue;
      void call<FinishingTournamentState | null>('getFinishingTournament', { tournamentId: tournament.id })
        .then(result => { if (active && result) tournamentCache.set(result.id, { data: result, receivedAt: Date.now() }); })
        .catch(() => { /* A failed preload is retried when the player selects it. */ });
    }
    return () => { active = false; };
  }, [data, tournamentCache, overviewOnly]);
  const offset = useMemo(() => data ? data.serverTime - (data.clientReceivedAt ?? Date.now()) : 0, [data?.serverTime, data?.clientReceivedAt]);
  async function buy() {
    if (!data || busy) return;
    setBusy(true); setError('');
    try { await passRedirect('infinitepay-checkout', { kind: 'tournament', quantity: 1, tournamentId: data.id, requestId: crypto.randomUUID() }); }
    catch (cause) { setError(errorMessage(cause)); setBusy(false); }
  }
  async function openProfile(player: TournamentPlayer) { if(redirectOwnProfile(player.uid))return;
    setSelected(player); window.scrollTo({ top: 0, behavior: 'instant' });
    try {
      const profile = await call<PublicProfile | null>('getPublicProfile', { uid: player.uid });
      if (profile) setSelected(current => current?.uid === player.uid ? { ...current, ...profile } : current);
    } catch { /* The ranking already supplies the public profile. */ }
  }
  if (loading && (!data || (tournamentId !== null && data.id !== tournamentId))) return <Loading label="Carregando torneio…"/>;
  if (!data) return error ? <ErrorNotice message={error} retry={retry}/> : <section className="card daily-empty"><Trophy size={34}/><h2>Novos torneios em breve.</h2></section>;
  if (selected) return <div className="public-profile-view"><button type="button" className="public-profile-back" onClick={() => {cancelProfileOpen();setSelected(null);}}><ArrowLeft size={18}/>Voltar ao torneio</button><div className="page-heading"><h1>Perfil público<span>.</span></h1></div>{profileOpenNotice}<ProfileOverview profile={selected} lastClosedPrediction={lastClosedPrediction} today={today} onOpenProfile={openPublicProfile}/></div>;
  const now = Date.now() + offset;
  const upcoming = now < Date.parse(data.startsAt);
  const ended = now >= Date.parse(data.endsAt);
  const showDetails = details && data.enrolled && !ended;
  const endDay = dateLabel(new Date(Date.parse(data.endsAt) - 1).toISOString());
  const matchDays = data.matchDays ?? [...new Set(data.predictions.map(game => game.dayId))].sort();
  const dayCount = matchDays.length || 3;
  const duration = matchDays.length === 1 ? dateLabel(`${matchDays[0]}T12:00:00-03:00`) : matchDays.length ? `${dateLabel(`${matchDays[0]}T12:00:00-03:00`)} a ${dateLabel(`${matchDays.at(-1)}T12:00:00-03:00`)}` : `${dateLabel(data.startsAt)} a ${endDay}`;
  const startTime = tournamentTime(data.startsAt);
  const startWeekday = new Date(data.startsAt).toLocaleDateString('pt-BR', { weekday: 'long', timeZone: 'America/Sao_Paulo' });
  const settledCount = data.predictions.filter(game => game.status === 'settled').length;
  const predictionsPublished = data.predictionsPublished ?? data.predictions.length > 0;
  const theme = data.metric === 'mixed' && data.name === 'EL CLÁSSICO' ? 'el-clasico' : data.metric === 'classic' && /champions league|liga dos campeões/i.test(data.name) ? 'champions' : data.metric === 'classic' && /liga europa|europa league/i.test(data.name) ? 'europa' : undefined;
  const helpButton = <button type="button" className="icon-button" aria-label={`Ver regras do ${data.name}`} onClick={() => setRules(true)}><CircleHelp size={21}/></button>;
  const rulesModal = <Modal open={rules} onOpenChange={setRules} title="Regras do torneio">
    <div className="tournament-rules" data-tournament-theme={theme}>
      <div className="tournament-payout-notice"><Wallet size={24} aria-hidden="true"/><div><h3>Como você recebe o prêmio</h3><p>Após o torneio, o prêmio é pago via <strong>Pix para a chave do e-mail da sua conta</strong>. Se esse e-mail não for uma chave Pix, <strong>solicitaremos sua chave por e-mail</strong>.</p></div></div>
      <p><strong>{duration} · {data.predictionCount} palpites · Entrada {money(data.entryCents)}.</strong> Inscrição confirmada após o pagamento.</p>
      <p>Cada acerto vale <strong>1 ponto</strong>. Vence quem somar mais acertos; empate divide o prêmio. Os palpites não alteram PontosRank, greens, reds ou XP.</p>
      <p>Inscreva-se até <strong>{startTime} de Brasília</strong> no dia de início. Cada palpite fecha no início do jogo e não pode ser alterado após confirmado.</p>
      <p><strong>Recompensas: prêmio em Pix, caixas e drops.</strong> O prêmio em dinheiro soma {money(data.entryCents)} por inscrito; total atual: <strong>{money(data.prizeCents)}</strong>.</p>
      
      <details className="tournament-rules-details"><summary>Detalhes dos palpites</summary>
      {(!data.metric || data.metric === 'shots') && <p><strong>Quem terá mais finalizações?</strong> Casa é o mandante, Fora é o visitante e Empate significa totais iguais. Valem as finalizações totais nos 90 minutos e acréscimos, incluindo chutes para fora e bloqueados.</p>}
      {data.metric === 'classic' && <p><strong>Partida Clássica — Quem vence?</strong> Casa é vitória do mandante, X é empate e Fora é vitória do visitante. Vale o placar ao fim dos 90 minutos e acréscimos.</p>}
      {data.metric === 'cards' && <p><strong>Quem terá mais cartões?</strong> Casa é o mandante, Fora é o visitante e Empate significa totais iguais. Valem os cartões amarelos e vermelhos recebidos pelos jogadores nos 90 minutos e acréscimos.</p>}
      {data.metric === 'mixed' && <><p><strong>Barcelona x Real Madrid.</strong> Casa representa o Barcelona e Fora representa o Real Madrid. X significa empate nos palpites comparativos. No primeiro gol, Nenhum significa partida sem gols.</p><p>Os 20 palpites incluem resultado, estatísticas, faixas de finalizações e defesas, e respostas Sim ou Não. Valem os 90 minutos e acréscimos; o primeiro tempo inclui seus acréscimos. Finalizações incluem chutes para fora e bloqueados; jogadores que não entrarem em campo têm zero finalizações. As defesas somam as dos goleiros de cada equipe.</p><p>Nos palpites de cartões, contam os amarelos e os vermelhos diretos dos jogadores em campo. A expulsão por segundo amarelo conta os dois amarelos, sem somar outro vermelho ao total; ela vale como cartão vermelho no palpite sobre expulsão. Mais de 5,5 cartões significa pelo menos 6.</p></>}
      </details>
    </div>
  </Modal>;
  const overviewGrid = desktop && !overviewOnly && !showDetails;
  const choices = data.availableTournaments?.length ? data.availableTournaments : [{id:data.id,name:data.name}];
  const overviewStart = Math.floor(Math.max(0,choices.findIndex(item=>item.id===data.id))/2)*2;
  return <div className={`finishing-tournament-page${overviewOnly?' tournament-overview-item':''}${overviewGrid?' has-tournament-grid':''}`} data-tournament-theme={overviewGrid?undefined:theme}>
    {showDetails ? <>
      <button type="button" className="public-profile-back" onClick={() => setDetails(false)}><ArrowLeft size={18}/>Voltar aos torneios</button>
      <div className="page-heading tournament-detail-heading"><div><span className="eyebrow">{duration} · {dayCount} {dayCount === 1 ? 'DIA' : 'DIAS'}</span><h1>{data.name}<span>.</span></h1></div>{helpButton}</div>
      <div className="tournament-detail-layout">
      <section className="card tournament-predictions"><div className="tournament-section-heading"><h2><ListChecks size={20}/>Palpites do torneio</h2><span>{data.ownRank?.correctAnswers ?? 0} acertos</span></div>
        {data.predictions.length ? <TournamentPredictions data={data} offset={offset} today={today} onSaved={result => {
          tournamentCache.set(result.id, { data: result, receivedAt: Date.now() }); setData(result);
        }}/>
          : <div className="tournament-predictions-empty"><Crosshair size={34} aria-hidden="true"/><h3>Os palpites serão publicados em breve.</h3><p>Os {data.predictionCount} palpites deste torneio aparecerão aqui.</p></div>}
      </section>
      <section className="tournament-ranking" aria-label={`Ranking do ${data.name}`}><div className="tournament-section-heading"><h2><Trophy size={20}/>Ranking do torneio</h2><button type="button" className="icon-button" aria-label="Atualizar torneio" disabled={loading} onClick={retry}><RefreshCw size={18} className={loading ? 'spin' : ''}/></button></div>
        <div className="card global-ranking-card" aria-busy={loading}><div className="global-ranking-heading"><span>TOP 10 / JOGADOR</span><span>ACERTOS</span></div>
          <ol className="global-ranking-list">{data.players.map(player => <TournamentRankingRow settledCount={settledCount} key={player.uid} player={player} ownUid={ownUid} onOpen={player => void openProfile(player)}/>)}</ol>
          {data.ownRank && data.ownRank.position > 10 && <div className="global-ranking-own"><div className="global-ranking-own-label">SUA POSIÇÃO</div><ol className="global-ranking-list"><TournamentRankingRow settledCount={settledCount} player={data.ownRank} ownUid={ownUid} onOpen={player => void openProfile(player)}/></ol></div>}
          {data.players.length === 0 && <div className="global-ranking-empty">Os inscritos aparecerão aqui.</div>}
        </div>
      </section>
      </div>
    </> : <>
      {!overviewOnly && <div className="page-heading"><h1>Torneios<span>.</span></h1></div>}
      {overviewGrid ? <div className="tournament-overview-grid">
        {choices.slice(overviewStart,overviewStart+2).map(item=><FinishingTournament key={item.id} ownUid={ownUid} refreshTick={refreshTick} today={today} lastClosedPrediction={lastClosedPrediction} overviewOnly initialTournamentId={item.id} initialData={item.id===data.id?data:tournamentCache.get(item.id)?.data} onOpenDetails={result=>{tournamentCache.set(result.id,{data:result,receivedAt:Date.now()});setData(result);setTournamentId(result.id);setDetails(true);}}/>)}
      </div> : <section className={`card finishing-tournament-card${data.enrolled ? ' is-enrolled' : ''}${ended ? ' is-finished' : ''}`} aria-label={data.name}>
        <div className="tournament-card-top">{!upcoming&&(!data.enrolled || ended) && <span className="tournament-status"><Crosshair size={15}/> {ended ? data.name : 'EM ANDAMENTO'}</span>}{helpButton}</div>
        <div className="tournament-hero"><div className="tournament-hero-copy">{(!ended && upcoming && theme !== 'champions' && theme !== 'el-clasico' && theme !== 'europa') && <span className="tournament-event-eyebrow">O DESAFIO DO FIM DE SEMANA</span>}<h2>{ended?'Torneio encerrado':data.name}<span>.</span></h2><div className="tournament-date"><CalendarDays size={17}/><span>{predictionsPublished ? duration : dateLabel(data.startsAt)} · início {['sábado', 'domingo'].includes(startWeekday) ? 'no' : 'na'} {startWeekday} às {startTime}</span></div></div>
          <div className="tournament-prize"><Trophy size={46} strokeWidth={1.5} aria-hidden="true"/><span>{upcoming?'Premiação Total no Momento':'Premiação Total do torneio'}</span><strong>{money(data.prizeCents)}</strong></div>
        </div>
        <div className="tournament-event-stats"><span><ListChecks size={16}/><strong>{data.predictionCount}</strong> palpites</span><span><CalendarDays size={16}/><strong>{dayCount}</strong> {dayCount === 1 ? 'dia' : 'dias'}</span><span><Users size={16}/><strong>{data.participants}</strong> inscritos</span></div>
        {(!data.metric || data.metric === 'shots') && <p className="tournament-pool-note">Escolha seus resultados e dispute o ranking.</p>}
        {!ended && <div className="tournament-clock-block"><span><Clock3 size={16}/>{upcoming ? 'O TORNEIO COMEÇA EM' : 'O TORNEIO ENCERRA EM'}</span><TournamentCountdown until={Date.parse(upcoming ? data.startsAt : data.endsAt)} offset={offset} onReached={retry}/></div>}
        <div className="tournament-entry">
          {ended ? <div className="tournament-final-result" aria-label="Resultado final do torneio">
            {data.winners?.length ? <><span className="tournament-winner-label"><Trophy size={16} aria-hidden="true"/>{data.winners.length > 1 ? 'Vencedores' : 'Vencedor'}</span><ul className="tournament-winners">{data.winners.map(winner => <li key={winner.uid}>
              <Avatar name={winner.username} color={winner.avatarColor} imageUrl={winner.avatarUrl} borderStyle={winner.passBorderStyle}/>
              <strong className={`tournament-winner-name pass-name-${winner.passNameStyle ?? 'none'}`}><UsernameText name={winner.username} font={winner.usernameFont} fitToWidth/></strong>
              <strong className="tournament-winner-points">{winner.correctAnswers} <small>pts</small></strong>
            </li>)}</ul></> : <p className="tournament-final-pending">Resultado final em apuração.</p>}
          </div> : <>
          {(data.enrolled || data.registrationOpen && upcoming) && <div className="tournament-entry-price"><span>ENTRADA ÚNICA</span><strong>{money(data.entryCents)}</strong></div>}
          {data.enrolled ? predictionsPublished ? <button type="button" className="primary-button tournament-enter-button" onClick={() => onOpenDetails ? onOpenDetails(data) : setDetails(true)}>Ver palpites e ranking<ArrowRight size={19}/></button>
            : <button type="button" className="primary-button tournament-enter-button" disabled><Check size={19}/>Você está inscrito</button>
            : data.registrationOpen && upcoming ? <button type="button" className="primary-button tournament-enter-button" disabled={busy} onClick={() => void buy()}>{busy ? <LoaderCircle size={19} className="spin"/> : <QrCode size={19}/>} {busy ? 'Abrindo pagamento…' : 'Inscrever-se no torneio'}</button>
            : <p className="tournament-closed">As inscrições deste torneio encerraram.</p>}
          </>}
        </div>
      </section>}
    </>}
    {!showDetails && !overviewOnly && <TournamentSelector perPage={desktop?2:1} tournaments={data.availableTournaments} value={data.id} disabled={loading || busy} onChange={id => {
      const cached = tournamentCache.get(id);
      if (cached && Date.now() - cached.receivedAt < 30000) setData(cached.data);
      setDetails(false); setRules(false); setTournamentId(id);
    }}/>}
    {error && <ErrorNotice message={error} retry={retry}/>}{rulesModal}
  </div>;
}
