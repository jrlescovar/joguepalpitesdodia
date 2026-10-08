import { useEffect, useRef, useState } from 'react';
import { ArrowLeft, ChevronLeft, ChevronRight, CircleHelp, Crown, RefreshCw, Swords, Trophy } from 'lucide-react';
import { call, errorMessage } from './backend';
import { Avatar, ErrorNotice, Modal } from './components';
import UsernameText from './UsernameText';
import ProfileOverview from './ProfileOverview';
import {usePublicProfileNavigation} from './usePublicProfileNavigation';
import type { PublicProfile } from './types';
import './arena.css';
import { pollWhileVisible } from './visiblePolling';
import WeeklyArena, { ArenaWeekHero, type ArenaWeek } from './WeeklyArena';

type ArenaPlayer = PublicProfile & { points: number; greens: number; seed: number; qualifyingPoints: number };
export type ArenaState = { dayId: string; status: 'open' | 'finished'; winnerId: string | null; qualified: boolean; settled: number; total: number; king: (PublicProfile & { wonOn: string }) | null; players: ArenaPlayer[]; week?:ArenaWeek };
type ArenaHistoryEntry = { dayId: string; winner: PublicProfile; points: number; greens: number };
const HISTORY_PAGE_SIZE = 5;
function ArenaDailyRow({player,position,ownUid,winnerId,onOpen}:{player:ArenaPlayer;position:number;ownUid:string;winnerId:string|null;onOpen:(player:PublicProfile)=>void}) {
  return <li className={player.uid===ownUid?'arena-is-me is-me':''}><button type="button" onClick={()=>onOpen(player)} aria-label={`Abrir perfil de ${player.username}, ${player.points} pontos na Arena`}><span className={`arena-position global-rank-position${position===1?' arena-first':position===2?' arena-second':position===3?' arena-third':''}`}>{player.uid===winnerId?<Crown size={19}/>: `#${position}`}</span><Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl} borderStyle={player.passBorderStyle}/><span className="arena-player global-rank-player"><strong className={`pass-name-${player.passNameStyle??'none'}`}><UsernameText name={player.username} font={player.usernameFont}/></strong><small>{player.greens} greens{player.uid===winnerId?' · Vencedor do dia':''}</small></span><strong className="arena-points global-rank-points">{player.points}</strong></button></li>;
}
export default function Arena({ ownUid, today, lastClosedPrediction, refreshTick }: { ownUid: string; today: string; lastClosedPrediction: string | null; refreshTick: number }) {
  const [data, setData] = useState<ArenaState | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const [arenaView,setArenaView]=useState<'daily'|'weekly'>('daily');
  const [weekView,setWeekView]=useState<'standings'|'bracket'>('standings');
  const [showHelp, setShowHelp] = useState(false);
  const [showHistory, setShowHistory] = useState(false);
  const [selected, setSelected] = useState<PublicProfile | null>(null);
  const {openPublicProfile,cancelProfileOpen,profileOpenNotice}=usePublicProfileNavigation(setSelected);
  const [history, setHistory] = useState<ArenaHistoryEntry[]>([]);
  const [historyLoading, setHistoryLoading] = useState(true);
  const [historyError, setHistoryError] = useState('');
  const [historyHasMore, setHistoryHasMore] = useState(false);
  const [historyPage, setHistoryPage] = useState(0);
  const historyRequest = useRef(0);
  const historyButton = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    let active = true;
    async function refresh() {
      try { const next = await call<ArenaState | null>('getArena'); if (active) { setData(next); setError(''); } return next?.week ? next.week.status !== 'finished' : next?.status !== 'finished'; }
      catch (cause) { if (active) setError(errorMessage(cause)); return true; }
      finally { if (active) setLoading(false); }
    }
    setLoading(true);
    const stop = pollWhileVisible(refresh, 30000, () => document.visibilityState === 'visible');
    return () => { active = false; stop(); };
  }, [refreshTick, reload, today]);
  useEffect(() => {
    let active = true;
    historyRequest.current++;
    setHistoryLoading(true);
    void call<ArenaHistoryEntry[]>('getArenaHistory').then(rows => {
      if (!active) return;
      setHistory(rows.slice(0, 10));
      setHistoryHasMore(rows.length > 10);
      setHistoryPage(0);
      setHistoryError('');
    }).catch(cause => { if (active) setHistoryError(errorMessage(cause)); })
      .finally(() => { if (active) setHistoryLoading(false); });
    return () => { active = false; };
  }, [refreshTick, reload, today]);
  async function nextHistoryPage() {
    if (historyLoading) return;
    const nextPage = historyPage + 1;
    if (nextPage * HISTORY_PAGE_SIZE < history.length) { setHistoryPage(nextPage); return; }
    const beforeDay = history.at(-1)?.dayId;
    if (!beforeDay || !historyHasMore) return;
    const request = ++historyRequest.current;
    setHistoryLoading(true);
    try {
      const rows = await call<ArenaHistoryEntry[]>('getArenaHistory', { beforeDay });
      if (request !== historyRequest.current) return;
      setHistory(previous => [...previous, ...rows.slice(0, 10)]);
      setHistoryHasMore(rows.length > 10);
      if (rows.length > 0) setHistoryPage(nextPage);
      setHistoryError('');
    } catch (cause) { if (request === historyRequest.current) setHistoryError(errorMessage(cause)); }
    finally { if (request === historyRequest.current) setHistoryLoading(false); }
  }
  function openProfile(player: PublicProfile) { setSelected(player); window.scrollTo({ top: 0, behavior: 'instant' }); }
  const weekday=new Date(`${data?.dayId ?? today}T12:00:00Z`).getUTCDay();
  const hasDailyArena=weekday>=1&&weekday<=4;
  const showDailyArena=hasDailyArena&&(!data?.week||arenaView==='daily');
  if (selected) return <div className="public-profile-view"><button className="public-profile-back" onClick={() => {cancelProfileOpen();setSelected(null);}}><ArrowLeft size={18}/>Voltar à Arena</button><div className="page-heading"><h1>Perfil público<span>.</span></h1></div>{profileOpenNotice}<ProfileOverview profile={selected} today={today} lastClosedPrediction={lastClosedPrediction} onOpenProfile={openPublicProfile}/></div>;
  return <div className="arena-page global-ranking-page">
    <div className="page-heading"><h1>Arena<span>.</span></h1><div className="arena-heading-actions"><button ref={historyButton} type="button" className="icon-button" aria-label="Histórico Vencedor do Dia" onClick={() => setShowHistory(true)}><Swords size={20}/></button><button type="button" className="icon-button" aria-label="Como funciona a Arena" onClick={() => setShowHelp(true)}><CircleHelp size={20}/></button><button type="button" className="icon-button" disabled={loading} aria-label="Atualizar Arena" onClick={() => setReload(value => value + 1)}><RefreshCw size={19} className={loading ? 'spin' : ''}/></button></div></div>
    <Modal open={showHelp} onOpenChange={setShowHelp} title="Como funciona a Arena"><div className="arena-help"><p>De <strong>segunda a quinta</strong>, os 100 primeiros do Ranking Global na abertura de cada dia disputam a Arena tradicional. Todos podem acompanhar a tabela e o vencedor diário. Os três primeiros do dia continuam recebendo <strong>+30, +20 e +10 PontosRank</strong>.</p><p>A classificação semanal soma os pontos ganhos nos palpites nesses quatro dias. Os <strong>8 melhores</strong> avançam: Q1 (1º × 8º), Q2 (4º × 5º), Q3 (2º × 7º) e Q4 (3º × 6º).</p><p><strong>Sexta:</strong> quartas. <strong>Sábado:</strong> vencedor de Q1 × Q2 e vencedor de Q3 × Q4. <strong>Domingo:</strong> final. Cada fase usa apenas os pontos dos palpites normais daquele dia, sem carregar o placar da fase anterior.</p><p>A apuração só encerra quando todos os resultados do dia estiverem confirmados. Sem resultados ou com partidas pendentes, o chaveamento aguarda. A final concede <strong>1 título e a medalha Campeão da Arena</strong>.</p><p>Na classificação semanal, os desempates são greens, nível e menor ID. No mata-mata, são greens do dia e melhor posição na classificação semanal. As vagas ficam fixas após a classificação.</p></div></Modal>
    {error && <ErrorNotice message={error} retry={() => setReload(value => value + 1)}/>}
    {loading && !data && <p role="status">Carregando Arena…</p>}
    {data && <>
      {data.week&&hasDailyArena&&<div className="arena-week-tabs arena-mode-tabs" role="group" aria-label="Visão da Arena"><button type="button" aria-pressed={arenaView==='daily'} onClick={()=>setArenaView('daily')}><Swords size={18}/>Arena do Dia</button><button type="button" aria-pressed={arenaView==='weekly'} onClick={()=>setArenaView('weekly')}><Trophy size={18}/>Classificação</button></div>}
      {data.week&&!showDailyArena&&<WeeklyArena week={data.week} ownUid={ownUid} onOpen={openProfile} view={weekView} onViewChange={setWeekView}/>}

      {data.players.length>0&&showDailyArena&&<>
      {data.week&&<ArenaWeekHero startsOn={data.week.startsOn}/>}
      <section className="card arena-table global-ranking-card" aria-busy={loading}><header><span><Swords size={19}/>Arena do Dia {data.dayId.slice(8, 10)}/{data.dayId.slice(5, 7)}</span><strong>{data.settled}/{data.total}</strong></header>
        <div className="arena-columns global-ranking-heading"><span>JOGADOR</span><span>PTS DO DIA</span></div>
        <ol className="global-ranking-list">{data.players.slice(0,10).map((player,index)=><ArenaDailyRow key={player.uid} player={player} position={index+1} ownUid={ownUid} winnerId={data.winnerId} onOpen={openProfile}/>)}</ol>
        {data.players.findIndex(player=>player.uid===ownUid)>=10&&<div className="global-ranking-own"><div className="global-ranking-own-label">SUA POSIÇÃO</div><ol className="global-ranking-list"><ArenaDailyRow player={data.players.find(player=>player.uid===ownUid)!} position={data.players.findIndex(player=>player.uid===ownUid)+1} ownUid={ownUid} winnerId={data.winnerId} onOpen={openProfile}/></ol></div>}
      </section>
      <p className="arena-qualification">{data.qualified ? 'Você está classificado para a Arena do dia!' : 'A Arena diária é disputada pelo top 100 na abertura do dia.'}</p>
      </>}
    </>}
    <Modal open={showHistory} onOpenChange={setShowHistory} title="Histórico Vencedor do Dia" className="arena-history-dialog" onCloseAutoFocus={event=>{event.preventDefault();historyButton.current?.focus({preventScroll:true});}}>
    <section className="arena-history" aria-label="Histórico da Arena">
      {historyError && <ErrorNotice message={historyError} retry={() => setReload(value => value + 1)}/>}
      {historyLoading && history.length === 0 && <p className="arena-history-empty" role="status">Carregando campeões…</p>}
      {!historyLoading && !historyError && history.length === 0 && <p className="arena-history-empty">Os campeões aparecerão aqui após a primeira Arena encerrada.</p>}
      {history.length > 0 && <ol className="arena-history-list">{history.slice(historyPage * HISTORY_PAGE_SIZE, (historyPage + 1) * HISTORY_PAGE_SIZE).map(entry => <li key={entry.dayId}>
        <button type="button" className="arena-history-card card" onClick={() => openProfile(entry.winner)} aria-label={`Abrir perfil de ${entry.winner.username}, campeão da Arena de ${entry.dayId.slice(8, 10)}/${entry.dayId.slice(5, 7)}`}>
          <span className="arena-history-date">{entry.dayId.slice(8, 10)}/{entry.dayId.slice(5, 7)}</span>
          <Avatar name={entry.winner.username} color={entry.winner.avatarColor} imageUrl={entry.winner.avatarUrl} borderStyle={entry.winner.passBorderStyle}/>
          <span className="arena-history-player"><strong className={`pass-name-${entry.winner.passNameStyle ?? 'none'}`}><UsernameText name={entry.winner.username} font={entry.winner.usernameFont}/></strong><small>{entry.greens} greens</small></span>
          <span className="arena-history-score"><Crown size={16}/><strong>{entry.points} pts</strong></span>
        </button>
      </li>)}</ol>}
      {(history.length > HISTORY_PAGE_SIZE || historyHasMore) && <nav className="arena-history-pagination" aria-label="Páginas do Histórico da Arena">
        <button type="button" className="icon-button" aria-label="Página anterior do histórico da Arena" disabled={historyLoading || historyPage === 0} onClick={() => setHistoryPage(page => page - 1)}><ChevronLeft size={20}/></button>
        <span role="status">{historyLoading ? 'Carregando…' : `Página ${historyPage + 1}${historyHasMore ? '' : ` de ${Math.ceil(history.length / HISTORY_PAGE_SIZE)}`}`}</span>
        <button type="button" className="icon-button" aria-label="Próxima página do histórico da Arena" disabled={historyLoading || (!historyHasMore && (historyPage + 1) * HISTORY_PAGE_SIZE >= history.length)} onClick={() => void nextHistoryPage()}><ChevronRight size={20}/></button>
      </nav>}
    </section>
    </Modal>
  </div>;
}







