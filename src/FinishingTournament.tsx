import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ArrowLeft, ArrowRight, CalendarDays, Check, CircleHelp, Clock3, Crosshair, ListChecks, LoaderCircle, QrCode, RefreshCw, Trophy, Users, Wallet } from 'lucide-react';
import { call, errorMessage, invalidateReads, passRedirect } from './backend';
import { Avatar, ErrorNotice, Loading, Modal } from './components';
import UsernameText from './UsernameText';
import ProfileOverview from './ProfileOverview';
import {usePublicProfileNavigation} from './usePublicProfileNavigation';
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

function TournamentRankingRow({ player, ownUid, onOpen }: { player: TournamentPlayer; ownUid: string; onOpen: (player: TournamentPlayer) => void }) {
  return <li className={player.uid === ownUid ? 'is-me' : ''}><button type="button" onClick={() => onOpen(player)} aria-label={`Abrir perfil de ${player.username}, posição ${player.position}, ${player.correctAnswers} acertos`}>
    <span className={`global-rank-position${player.position>=10&&player.position<=99?' tournament-position-two-digits':''}`}>#{player.position}</span>
    <Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl} borderStyle={player.passBorderStyle}/>
    <span className="global-rank-player"><strong className={`pass-name-${player.passNameStyle ?? 'none'}`}><UsernameText name={player.username} font={player.usernameFont}/></strong></span>
    <strong className="tournament-hits">{player.correctAnswers}<small> / 21</small></strong>
  </button></li>;
}

export default function FinishingTournament({ ownUid, refreshTick, today, lastClosedPrediction }: { ownUid: string; refreshTick: number; today: string; lastClosedPrediction: string | null }) {
  const [data, setData] = useState<FinishingTournamentState | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const [details, setDetails] = useState(false);
  const [rules, setRules] = useState(false);
  const [busy, setBusy] = useState(false);
  const [selected, setSelected] = useState<PublicProfile | null>(null);
  const {openPublicProfile,cancelProfileOpen,profileOpenNotice}=usePublicProfileNavigation(setSelected);
  const retry = useCallback(() => { invalidateReads(); setReload(value => value + 1); }, []);
  useEffect(() => {
    let active = true;
    setLoading(true); setError('');
    call<FinishingTournamentState | null>('getFinishingTournament')
      .then(result => { if (active) setData(result); })
      .catch(cause => { if (active) setError(errorMessage(cause)); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [ownUid, refreshTick, reload]);
  const offset = useMemo(() => data ? data.serverTime - (data.clientReceivedAt ?? Date.now()) : 0, [data?.serverTime, data?.clientReceivedAt]);
  async function buy() {
    if (!data || busy) return;
    setBusy(true); setError('');
    try { await passRedirect('infinitepay-checkout', { kind: 'tournament', quantity: 1, tournamentId: data.id, requestId: crypto.randomUUID() }); }
    catch (cause) { setError(errorMessage(cause)); setBusy(false); }
  }
  async function openProfile(player: TournamentPlayer) {
    setSelected(player); window.scrollTo({ top: 0, behavior: 'instant' });
    try {
      const profile = await call<PublicProfile | null>('getPublicProfile', { uid: player.uid });
      if (profile) setSelected(current => current?.uid === player.uid ? { ...current, ...profile } : current);
    } catch { /* The ranking already supplies the public profile. */ }
  }
  if (loading && !data) return <Loading label="Carregando torneio…"/>;
  if (!data) return error ? <ErrorNotice message={error} retry={retry}/> : <section className="card daily-empty"><Trophy size={34}/><h2>Novos torneios em breve.</h2></section>;
  if (selected) return <div className="public-profile-view"><button type="button" className="public-profile-back" onClick={() => {cancelProfileOpen();setSelected(null);}}><ArrowLeft size={18}/>Voltar ao torneio</button><div className="page-heading"><h1>Perfil público<span>.</span></h1></div>{profileOpenNotice}<ProfileOverview profile={selected} lastClosedPrediction={lastClosedPrediction} today={today} onOpenProfile={openPublicProfile}/></div>;
  const now = Date.now() + offset;
  const upcoming = now < Date.parse(data.startsAt);
  const ended = now >= Date.parse(data.endsAt);
  const endDay = dateLabel(new Date(Date.parse(data.endsAt) - 1).toISOString());
  const matchDays = [...new Set(data.predictions.map(game => game.dayId))].sort();
  const dayCount = matchDays.length || 3;
  const duration = matchDays.length ? `${dateLabel(`${matchDays[0]}T12:00:00-03:00`)} a ${dateLabel(`${matchDays.at(-1)}T12:00:00-03:00`)}` : `${dateLabel(data.startsAt)} a ${endDay}`;
  const startTime = tournamentTime(data.startsAt);
  const startWeekday = new Date(data.startsAt).toLocaleDateString('pt-BR', { weekday: 'long', timeZone: 'America/Sao_Paulo' });
  const predictionsPublished = data.predictionsPublished ?? data.predictions.length > 0;
  const helpButton = <button type="button" className="icon-button" aria-label={`Ver regras do ${data.name}`} onClick={() => setRules(true)}><CircleHelp size={21}/></button>;
  const rulesModal = <Modal open={rules} onOpenChange={setRules} title="Regras do torneio">
    <div className="tournament-rules"><div className="tournament-payout-notice"><Wallet size={24} aria-hidden="true"/><div><h3>Como você recebe o prêmio</h3><p>Após o fim do torneio, o prêmio será pago via <strong>Pix para a chave que corresponde ao e-mail usado para criar sua conta</strong>.</p><p>Se esse e-mail não estiver cadastrado como chave Pix, <strong>entraremos em contato por e-mail solicitando sua chave Pix</strong>.</p></div></div><p><strong>Entrada: {money(data.entryCents)}.</strong> Sua inscrição é confirmada após a aprovação do pagamento.</p>
      {predictionsPublished ? <p>O torneio acontece de <strong>{duration}</strong>, com <strong>{data.predictionCount} palpites em {dayCount} dias</strong>.</p>
        : <p>O torneio começa em <strong>{dateLabel(data.startsAt)}, {startWeekday}, às {startTime} de Brasília</strong>. Os palpites serão publicados em breve.</p>}
      <p>Vence quem tiver o <strong>maior número de acertos</strong> nos palpites deste torneio.</p>
      {data.metric !== 'cards' && <p><strong>Quem terá mais finalizações?</strong> Casa é o mandante, Fora é o visitante e Empate significa totais iguais. Valem as finalizações totais nos 90 minutos e acréscimos, incluindo chutes para fora e bloqueados.</p>}
      {data.metric === 'cards' && <p><strong>Quem terá mais cartões?</strong> Casa é o mandante, Fora é o visitante e Empate significa totais iguais. Valem os cartões amarelos e vermelhos recebidos pelos jogadores nos 90 minutos e acréscimos.</p>}
      <p>Cada acerto vale <strong>1 ponto apenas no torneio</strong>. Os palpites não alteram PontosRank, greens, reds ou XP. O prazo de cada partida encerra no início do jogo, no horário de Brasília. Depois de confirmado, o palpite não pode ser alterado.</p>
      <p>Acertos dos palpites deste torneio. Em caso de empate no primeiro lugar, o prêmio é dividido.</p>
      <p>A premiação soma <strong>{money(data.entryCents)} por inscrito</strong>. O valor total no momento é de <strong>{money(data.prizeCents)}</strong>. Quem vencer leva tudo. Se houver empate no maior número de acertos, o prêmio será dividido igualmente entre os primeiros colocados.</p>
      <p>As inscrições encerram no início do torneio, às <strong>{startTime} de Brasília</strong>.</p>
    </div>
  </Modal>;
  return <div className="finishing-tournament-page">
    {details && data.enrolled ? <>
      <button type="button" className="public-profile-back" onClick={() => setDetails(false)}><ArrowLeft size={18}/>Voltar aos torneios</button>
      <div className="page-heading tournament-detail-heading"><div><span className="eyebrow">{duration} · {dayCount} DIAS</span><h1>{data.name}<span>.</span></h1></div>{helpButton}</div>
      <section className="card tournament-predictions"><div className="tournament-section-heading"><h2><ListChecks size={20}/>Palpites do torneio</h2><span>{data.ownRank?.correctAnswers ?? 0} acertos</span></div>
        {data.predictions.length ? <TournamentPredictions data={data} offset={offset} today={today} onSaved={setData}/>
          : <div className="tournament-predictions-empty"><Crosshair size={34} aria-hidden="true"/><h3>Os palpites serão publicados em breve.</h3><p>Os {data.predictionCount} palpites deste torneio aparecerão aqui.</p></div>}
      </section>
      <section className="tournament-ranking" aria-label={`Ranking do ${data.name}`}><div className="tournament-section-heading"><h2><Trophy size={20}/>Ranking do torneio</h2><button type="button" className="icon-button" aria-label="Atualizar torneio" disabled={loading} onClick={retry}><RefreshCw size={18} className={loading ? 'spin' : ''}/></button></div>
        <div className="card global-ranking-card" aria-busy={loading}><div className="global-ranking-heading"><span>TOP 10 / JOGADOR</span><span>ACERTOS</span></div>
          <ol className="global-ranking-list">{data.players.map(player => <TournamentRankingRow key={player.uid} player={player} ownUid={ownUid} onOpen={player => void openProfile(player)}/>)}</ol>
          {data.ownRank && data.ownRank.position > 10 && <div className="global-ranking-own"><div className="global-ranking-own-label">SUA POSIÇÃO</div><ol className="global-ranking-list"><TournamentRankingRow player={data.ownRank} ownUid={ownUid} onOpen={player => void openProfile(player)}/></ol></div>}
          {data.players.length === 0 && <div className="global-ranking-empty">Os inscritos aparecerão aqui.</div>}
        </div>
      </section>
    </> : <>
      <div className="page-heading"><h1>Torneios<span>.</span></h1></div>
      <section className={`card finishing-tournament-card${data.enrolled ? ' is-enrolled' : ''}`} aria-label={data.name}>
        <div className="tournament-card-top">{!data.enrolled && <span className="tournament-status"><Crosshair size={15}/> {upcoming ? 'INSCRIÇÕES ABERTAS' : ended ? 'TORNEIO ENCERRADO' : 'EM ANDAMENTO'}</span>}{helpButton}</div>
        <div className="tournament-hero"><div className="tournament-hero-copy"><span className="tournament-event-eyebrow">{upcoming ? 'O DESAFIO DO FIM DE SEMANA' : ended ? 'DESAFIO CONCLUÍDO' : 'O DESAFIO ESTÁ VALENDO'}</span><h2>{data.name}<span>.</span></h2><div className="tournament-date"><CalendarDays size={17}/><span>{predictionsPublished ? duration : dateLabel(data.startsAt)} · início no {startWeekday} às {startTime}</span></div></div>
          <div className="tournament-prize"><Trophy size={46} strokeWidth={1.5} aria-hidden="true"/><span>Premiação total no momento</span><strong>{money(data.prizeCents)}</strong></div>
        </div>
        <div className="tournament-event-stats"><span><ListChecks size={16}/><strong>{data.predictionCount}</strong> palpites</span><span><CalendarDays size={16}/><strong>{dayCount}</strong> dias</span><span><Users size={16}/><strong>{data.participants}</strong> inscritos</span></div>
        <p className="tournament-pool-note">{data.metric === 'cards' ? 'Casa, empate ou fora: quem recebe mais cartões?' : 'Escolha seus resultados e dispute o ranking.'}</p>
        <p className="tournament-prize-explanation">Cada inscrição acrescenta {money(data.entryCents)} à premiação. Quem vencer leva tudo; em caso de empate, o prêmio é dividido.</p>
        {!ended && <div className="tournament-clock-block"><span><Clock3 size={16}/>{upcoming ? 'O TORNEIO COMEÇA EM' : 'O TORNEIO ENCERRA EM'}</span><TournamentCountdown until={Date.parse(upcoming ? data.startsAt : data.endsAt)} offset={offset} onReached={retry}/></div>}
        <div className="tournament-entry">
          {(data.enrolled || data.registrationOpen && upcoming) && <div className="tournament-entry-price"><span>ENTRADA ÚNICA</span><strong>{money(data.entryCents)}</strong></div>}
          {data.enrolled ? predictionsPublished ? <button type="button" className="primary-button tournament-enter-button" onClick={() => setDetails(true)}>Ver palpites e ranking<ArrowRight size={19}/></button>
            : <button type="button" className="primary-button tournament-enter-button" disabled><Check size={19}/>Você está inscrito</button>
            : data.registrationOpen && upcoming ? <button type="button" className="primary-button tournament-enter-button" disabled={busy} onClick={() => void buy()}>{busy ? <LoaderCircle size={19} className="spin"/> : <QrCode size={19}/>} {busy ? 'Abrindo pagamento…' : 'Inscrever-se no torneio'}</button>
            : <p className="tournament-closed">As inscrições deste torneio encerraram.</p>}
        </div>
      </section>
    </>}
    {error && <ErrorNotice message={error} retry={retry}/>}{rulesModal}
  </div>;
}
