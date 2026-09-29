import { useEffect, useState } from 'react';
import { ArrowLeft, Crown, RefreshCw, Swords } from 'lucide-react';
import { call, errorMessage } from './backend';
import { Avatar, brasiliaDate, ErrorNotice } from './components';
import UsernameText from './UsernameText';
import ProfileOverview from './ProfileOverview';
import type { PublicProfile } from './types';
import './arena.css';

type ArenaPlayer = PublicProfile & { points: number; greens: number; seed: number; qualifyingPoints: number };
export type ArenaState = { dayId: string; status: 'open' | 'finished'; winnerId: string | null; qualified: boolean; settled: number; total: number; king: (PublicProfile & { wonOn: string }) | null; players: ArenaPlayer[] };
export default function Arena({ ownUid, today, lastClosedPrediction, refreshTick }: { ownUid: string; today: string; lastClosedPrediction: string | null; refreshTick: number }) {
  const [data, setData] = useState<ArenaState | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const [selected, setSelected] = useState<PublicProfile | null>(null);
  useEffect(() => {
    let active = true;
    async function refresh() {
      try { const next = await call<ArenaState | null>('getArena'); if (active) { setData(next); setError(''); } }
      catch (cause) { if (active) setError(errorMessage(cause)); }
      finally { if (active) setLoading(false); }
    }
    setLoading(true); void refresh();
    const timer = window.setInterval(() => { if (document.visibilityState === 'visible') void refresh(); }, 30000);
    return () => { active = false; clearInterval(timer); };
  }, [refreshTick, reload, today]);
  function openProfile(player: PublicProfile) { setSelected(player); window.scrollTo({ top: 0, behavior: 'instant' }); }
  if (selected) return <div className="public-profile-view"><button className="public-profile-back" onClick={() => setSelected(null)}><ArrowLeft size={18}/>Voltar à Arena</button><div className="page-heading"><h1>Perfil público<span>.</span></h1></div><ProfileOverview profile={selected} today={today} lastClosedPrediction={lastClosedPrediction}/></div>;
  return <div className="arena-page">
    <div className="page-heading"><h1>Arena<span>.</span></h1><button className="icon-button" disabled={loading} aria-label="Atualizar Arena" onClick={() => setReload(value => value + 1)}><RefreshCw size={19} className={loading ? 'spin' : ''}/></button></div>
    {error && <ErrorNotice message={error} retry={() => setReload(value => value + 1)}/>}
    {loading && !data && <p role="status">Carregando Arena…</p>}
    {data && <>
      <section className="card arena-king"><Crown size={30}/><div><span className="eyebrow">REI DA ARENA</span>{data.king ? <button onClick={() => openProfile(data.king!)}><Avatar name={data.king.username} color={data.king.avatarColor} imageUrl={data.king.avatarUrl} borderStyle={data.king.passBorderStyle}/><strong className={`pass-name-${data.king.passNameStyle ?? 'none'}`}><UsernameText name={data.king.username} font={data.king.usernameFont}/></strong></button> : <strong>A coroa espera seu primeiro campeão</strong>}<p>{data.king ? `Título conquistado em ${brasiliaDate(data.king.wonOn)}. Mantido até o próximo campeão.` : 'Quem somar mais pontos no dia conquista o título.'}</p></div></section>
      <p className="arena-qualification">{data.qualified ? 'Você está classificado para a Arena!' : 'Você não está classificado para a Arena'}{!data.qualified && <small>Acompanhe os dez classificados e a disputa pela coroa.</small>}</p>
      <section className="card arena-table" aria-busy={loading}><header><span><Swords size={19}/>ARENA DO DIA</span><strong>{data.settled}/{data.total}</strong></header><div className="arena-round-info"><span>{brasiliaDate(data.dayId)}</span><strong>{data.status === 'finished' ? 'Rodada encerrada' : 'Em disputa'}</strong></div>
        <div className="arena-columns"><span>JOGADOR</span><span>PTS DO DIA</span></div>
        <ol>{data.players.map((player, index) => <li key={player.uid} className={player.uid === ownUid ? 'arena-is-me' : ''}><button onClick={() => openProfile(player)} aria-label={`Abrir perfil de ${player.username}, ${player.points} pontos na Arena`}><span className={`arena-position${index === 0 ? ' arena-first' : ''}`}>{player.uid === data.winnerId ? <Crown size={19}/> : `#${index + 1}`}</span><Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl} borderStyle={player.passBorderStyle}/><span className="arena-player"><strong className={`pass-name-${player.passNameStyle ?? 'none'}`}><UsernameText name={player.username} font={player.usernameFont}/></strong><small>{player.greens} greens{player.uid === data.winnerId ? ' · Campeão' : ''}</small></span><strong className="arena-points">{player.points}</strong></button></li>)}</ol>
      </section>
    </>}
  </div>;
}

