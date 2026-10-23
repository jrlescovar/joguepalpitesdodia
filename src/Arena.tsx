import { useEffect, useRef, useState } from 'react';
import { ArrowLeft, ChevronLeft, ChevronRight, CircleHelp, Crown, RefreshCw, Swords, Trophy } from 'lucide-react';
import { call, errorMessage } from './backend';
import { Avatar, ErrorNotice, Modal } from './components';
import UsernameText from './UsernameText';
import ProfileOverview from './ProfileOverview';
import {useOwnProfileRedirect,usePublicProfileNavigation} from './usePublicProfileNavigation';
import type { PublicProfile } from './types';
import './arena.css';
import { isDoublePointsDay } from './domain';
import { pollWhileVisible } from './visiblePolling';
import WeeklyArena, { WeeklyLigaHistory, type ArenaWeek } from './WeeklyArena';

type ArenaPlayer = PublicProfile & { points: number; greens: number; seed: number; qualifyingPoints: number };
export type ArenaState = { dayId: string; status: 'open' | 'finished'; winnerId: string | null; qualified: boolean; settled: number; total: number; king: (PublicProfile & { wonOn: string }) | null; players: ArenaPlayer[]; week?:ArenaWeek };
type ArenaHistoryEntry = { dayId: string; winner: PublicProfile; points: number; greens: number; totalEntries?: number };
const HISTORY_PAGE_SIZE = 5;
function ArenaDailyRow({player,position,ownUid,winnerId,onOpen}:{player:ArenaPlayer;position:number;ownUid:string;winnerId:string|null;onOpen:(player:PublicProfile)=>void}) {
  return <li className={player.uid===ownUid?'arena-is-me is-me':''}><button type="button" onClick={()=>onOpen(player)} aria-label={`Abrir perfil de ${player.username}, ${player.points} pontos na Liga`}><span className={`arena-position global-rank-position${position===1?' arena-first':position===2?' arena-second':position===3?' arena-third':''}`}>{player.uid===winnerId?<Crown size={19}/>: `#${position}`}</span><Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl} borderStyle={player.passBorderStyle}/><span className="arena-player global-rank-player"><strong className={`pass-name-${player.passNameStyle??'none'}`}><UsernameText name={player.username} font={player.usernameFont}/></strong></span><span className="arena-points global-rank-points"><strong>{player.points}</strong><small>{player.greens} greens</small></span></button></li>;
}
export default function Arena({ ownUid, today, lastClosedPrediction, refreshTick }: { ownUid: string; today: string; lastClosedPrediction: string | null; refreshTick: number }) {
  const [data, setData] = useState<ArenaState | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const [arenaView,setArenaView]=useState<'daily'|'weekly'>('daily');
  const [showHelp, setShowHelp] = useState(false);
  const [showHistory, setShowHistory] = useState(false);
  const [historyView,setHistoryView]=useState<'daily'|'weekly'>('daily');
  const [desktop,setDesktop]=useState(()=>window.matchMedia('(min-width: 1024px)').matches);
  const [selected, setSelected] = useState<PublicProfile | null>(null);
  const redirectOwnProfile=useOwnProfileRedirect();
  const {openPublicProfile,cancelProfileOpen,profileOpenNotice}=usePublicProfileNavigation(setSelected);
  const [history, setHistory] = useState<ArenaHistoryEntry[]>([]);
  const [historyLoading, setHistoryLoading] = useState(true);
  const [historyError, setHistoryError] = useState('');
  const [historyHasMore, setHistoryHasMore] = useState(false);
  const [historyPage, setHistoryPage] = useState(0);
  const [historyTotal, setHistoryTotal] = useState<number | null>(null);
  const historyRequest = useRef(0);
  const historyButton = useRef<HTMLButtonElement>(null);
  useEffect(()=>{
    const media=window.matchMedia('(min-width: 1024px)');
    const update=()=>setDesktop(media.matches);
    update();media.addEventListener('change',update);
    return()=>media.removeEventListener('change',update);
  },[]);
  useEffect(() => {
    let active = true;
    async function refresh() {
      try { const next = await call<ArenaState | null>('getArena'); if (active) { setData(next); setError(''); } return next?.status !== 'finished' || Boolean(next.week && next.week.status !== 'finished'); }
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
      setHistoryTotal(rows[0]?.totalEntries ?? (rows.length <= 10 ? rows.length : null));
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
      if (rows[0]?.totalEntries !== undefined) setHistoryTotal(rows[0].totalEntries);
      if (rows.length > 0) setHistoryPage(nextPage);
      setHistoryError('');
    } catch (cause) { if (request === historyRequest.current) setHistoryError(errorMessage(cause)); }
    finally { if (request === historyRequest.current) setHistoryLoading(false); }
  }
  function openHistory(view:'daily'|'weekly',button:HTMLButtonElement) {
    historyButton.current=button;setHistoryView(view);setShowHistory(true);
  }
  function openProfile(player: PublicProfile) { if(redirectOwnProfile(player.uid))return; setSelected(player); window.scrollTo({ top: 0, behavior: 'instant' }); }
  const showDailyArena=!data?.week||arenaView==='daily';
  if (selected) return <div className="public-profile-view"><button className="public-profile-back" onClick={() => {cancelProfileOpen();setSelected(null);}}><ArrowLeft size={18}/>Voltar à Liga</button><div className="page-heading"><h1>Perfil público<span>.</span></h1></div>{profileOpenNotice}<ProfileOverview profile={selected} today={today} lastClosedPrediction={lastClosedPrediction} onOpenProfile={openPublicProfile}/></div>;
  return <div className="arena-page global-ranking-page">
    <div className="page-heading"><h1>Liga<span>.</span></h1><div className="arena-heading-actions"><button type="button" className="icon-button" aria-label={desktop||showDailyArena?"Histórico Vencedor Liga do Dia":"Histórico Liga da Semana"} onClick={event=>openHistory(desktop||showDailyArena?'daily':'weekly',event.currentTarget)}><Swords size={20}/></button>{desktop&&data?.week&&<button type="button" className="icon-button" aria-label="Histórico Liga da Semana" onClick={event=>openHistory('weekly',event.currentTarget)}><Trophy size={20}/></button>}<button type="button" className="icon-button" aria-label="Como funciona a Liga" onClick={() => setShowHelp(true)}><CircleHelp size={20}/></button><button type="button" className="icon-button" disabled={loading} aria-label="Atualizar Liga" onClick={() => setReload(value => value + 1)}><RefreshCw size={19} className={loading ? 'spin' : ''}/></button></div></div>
    <Modal open={showHelp} onOpenChange={setShowHelp} title="Como funciona a Liga" className="liga-help-dialog"><div className="arena-help">
      <section className="liga-help-section"><h3><Swords size={20}/>Liga do Dia</h3><p><strong>Todos os dias</strong>, quem palpitou no dia anterior ou no dia atual participa da Liga do Dia. Todos podem acompanhar a tabela e o vencedor diário. Os 10 primeiros do dia recebem PontosRank, do 1º ao 10º: <strong>100, 85, 75, 50, 40, 30, 20, 15, 10 e 10</strong>. Em caso de empate nos pontos do dia, o primeiro desempate é a melhor posição no Ranking Global de PontosRank, registrada na abertura da Liga.</p></section>
      <section className="liga-help-section"><h3><Trophy size={20}/>Liga da Semana</h3><p>A <strong>Liga da Semana</strong> soma os pontos dos palpites de <strong>segunda a domingo</strong> dos participantes da Liga do Dia na segunda-feira. A entrada fica aberta durante a segunda e fecha na terça-feira; depois disso, ninguém mais entra naquela semana. O primeiro colocado recebe <strong>1 título e a medalha Liga da Semana</strong>.</p><p><strong>Eliminações a partir da semana de 26/10/2026:</strong> de segunda a sábado, os últimos entre os jogadores ainda ativos são eliminados pelo desempenho acumulado na Liga da Semana. A quantidade diária é o total de participantes menos 10, dividido por 6 e arredondado para baixo. O corte ocorre após o fim do dia e a confirmação de todos os resultados. No domingo não há corte.</p><p>Quem for eliminado continua na tabela, mantém os pontos e greens conquistados até o dia da eliminação e não soma novos pontos na Liga da Semana. Ainda pode vencer se terminar em primeiro. Seus palpites continuam valendo normalmente nas outras modalidades.</p><p>Na Liga da Semana, o primeiro desempate é a melhor posição atual no Ranking Global de PontosRank; depois, a quantidade de greens. A semana só encerra após a confirmação de todos os resultados dos sete dias.</p></section>
    </div></Modal>
    {error && <ErrorNotice message={error} retry={() => setReload(value => value + 1)}/>}
    {loading && !data && <p role="status">Carregando Liga…</p>}
    {data && <>
      {data.week&&!desktop&&<div className="arena-week-tabs arena-mode-tabs" role="group" aria-label="Visão da Liga"><button type="button" aria-pressed={arenaView==='daily'} onClick={()=>setArenaView('daily')}><Swords size={18}/>Liga do Dia</button><button type="button" aria-pressed={arenaView==='weekly'} onClick={()=>{setArenaView('weekly');}}><Trophy size={18}/>Liga da Semana</button></div>}
      <div className={`liga-tables${data.week?' liga-tables-with-week':''}`}>
      {(data.players.length>0||desktop)&&(desktop||showDailyArena)&&<div className="liga-daily-panel">
      <section className="card arena-table global-ranking-card" aria-busy={loading}><header><span><Swords size={19}/>Liga do Dia {data.dayId.slice(8, 10)}/{data.dayId.slice(5, 7)}</span><strong>{data.settled}/{data.total}</strong></header>
        <div className="arena-columns global-ranking-heading"><span>JOGADOR</span><span>PTS DO DIA</span></div>
        <ol className="global-ranking-list">{data.players.slice(0,10).map((player,index)=><ArenaDailyRow key={player.uid} player={player} position={index+1} ownUid={ownUid} winnerId={data.winnerId} onOpen={openProfile}/>)}</ol>
        {data.players.length===0&&<p className="muted liga-daily-empty">Nenhum jogador na Liga do Dia ainda.</p>}
        {data.players.findIndex(player=>player.uid===ownUid)>=10&&<div className="global-ranking-own"><div className="global-ranking-own-label">SUA POSIÇÃO</div><ol className="global-ranking-list"><ArenaDailyRow player={data.players.find(player=>player.uid===ownUid)!} position={data.players.findIndex(player=>player.uid===ownUid)+1} ownUid={ownUid} winnerId={data.winnerId} onOpen={openProfile}/></ol></div>}
      </section>
      <p className="arena-qualification">{data.qualified ? 'Você está participando da Liga do Dia!' : 'Palpite hoje para participar da Liga do Dia. Quem palpitou ontem também participa.'}</p>
      </div>}
      {data.week&&(desktop||!showDailyArena)&&<WeeklyArena week={data.week} ownUid={ownUid} onOpen={openProfile}/>}
      </div>
    </>}
    <Modal open={showHistory} onOpenChange={setShowHistory} title={historyView==='daily'?"Histórico Vencedor Liga do Dia":"Histórico Liga da Semana"} className="arena-history-dialog" onCloseAutoFocus={event=>{event.preventDefault();historyButton.current?.focus({preventScroll:true});}}>
    {historyView==='daily'?<section className="arena-history" aria-label="Histórico da Liga">
      {historyError && <ErrorNotice message={historyError} retry={() => setReload(value => value + 1)}/>}
      {historyLoading && history.length === 0 && <p className="arena-history-empty" role="status">Carregando campeões…</p>}
      {!historyLoading && !historyError && history.length === 0 && <p className="arena-history-empty">Os campeões aparecerão aqui após a primeira Liga do Dia encerrada.</p>}
      {history.length > 0 && <ol className="arena-history-list">{history.slice(historyPage * HISTORY_PAGE_SIZE, (historyPage + 1) * HISTORY_PAGE_SIZE).map(entry => <li key={entry.dayId}>
        <button type="button" className="arena-history-card card" onClick={() => openProfile(entry.winner)} aria-label={`Abrir perfil de ${entry.winner.username}, campeão da Liga de ${entry.dayId.slice(8, 10)}/${entry.dayId.slice(5, 7)}`}>
          <span className={`arena-history-date${isDoublePointsDay(entry.dayId)?" is-double-points":""}`} title={isDoublePointsDay(entry.dayId)?"Pontos em dobro":undefined}>{entry.dayId.slice(8, 10)}/{entry.dayId.slice(5, 7)}</span>
          <Avatar name={entry.winner.username} color={entry.winner.avatarColor} imageUrl={entry.winner.avatarUrl} borderStyle={entry.winner.passBorderStyle}/>
          <span className="arena-history-player"><strong className={`pass-name-${entry.winner.passNameStyle ?? 'none'}`}><UsernameText name={entry.winner.username} font={entry.winner.usernameFont}/></strong></span>
          <span className="arena-history-score"><strong>{entry.points} pts</strong><small>{entry.greens} greens</small></span>
        </button>
      </li>)}</ol>}
      {(history.length > HISTORY_PAGE_SIZE || historyHasMore) && <nav className="arena-history-pagination" aria-label="Páginas do Histórico da Liga">
        <button type="button" className="icon-button" aria-label="Página anterior do histórico da Liga" disabled={historyLoading || historyPage === 0} onClick={() => setHistoryPage(page => page - 1)}><ChevronLeft size={20}/></button>
        <span role="status" aria-label={historyLoading ? 'Carregando histórico' : `Página ${historyPage + 1} de ${historyTotal === null ? 'total em carregamento' : Math.ceil(historyTotal / HISTORY_PAGE_SIZE)}`}>{historyLoading ? 'Carregando…' : `${historyPage + 1}/${historyTotal === null ? '…' : Math.ceil(historyTotal / HISTORY_PAGE_SIZE)}`}</span>
        <button type="button" className="icon-button" aria-label="Próxima página do histórico da Liga" disabled={historyLoading || (!historyHasMore && (historyPage + 1) * HISTORY_PAGE_SIZE >= history.length)} onClick={() => void nextHistoryPage()}><ChevronRight size={20}/></button>
      </nav>}
    </section>:<WeeklyLigaHistory onOpen={player=>{setShowHistory(false);openProfile(player);}}/>}
    </Modal>
  </div>;
}







