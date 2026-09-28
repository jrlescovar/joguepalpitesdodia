import { useEffect, useState } from 'react';
import { ArrowLeft, RefreshCw, Shield, CircleHelp } from 'lucide-react';
import { call, errorMessage } from './backend';
import { Avatar, ErrorNotice, Modal } from './components';
import ProfileOverview from './ProfileOverview';
import { rankTier, rankTiers } from './rankTiers';
import RankEmblem from './RankEmblem';
import DailyBattle from './DailyBattle';
import type { PublicProfile } from './types';

type RankedPlayer = PublicProfile & { rankPoints: number; position: number };
type GlobalRankingPage = { players: RankedPlayer[]; ownRank: RankedPlayer | null };

function RankProgress({ points, position }: { points: number; position: number | null }) {
  const [showRanks, setShowRanks] = useState(false);
  const guide = <><button type="button" className="rank-guide-button" aria-label="Ver patentes e pontuações" onClick={() => setShowRanks(true)}><CircleHelp size={22}/></button><Modal open={showRanks} onOpenChange={setShowRanks} title="Patentes do Ranking"><div className="rank-guide-list">{rankTiers.map((item, index) => <div className="rank-guide-row" key={item.key}><RankEmblem points={item.min}/><strong>{item.name}</strong><span>{rankTiers[index + 1] ? `${item.min} a ${rankTiers[index + 1].min - 1} pts` : `${item.min} pts ou mais`}</span></div>)}</div></Modal></>;
  const tier = rankTier(points);
  const nextTier = rankTiers[rankTiers.findIndex(item => item.key === tier.key) + 1];
  if (!nextTier) return <section className="card rank-progress-card rank-progress-master" aria-label="Sua patente no Ranking Global">
    <div className="rank-progress-caption">SUA PATENTE</div>{guide}
    <div className="rank-progress-master-content"><RankEmblem points={points}/><div><strong>{tier.name}</strong><span>{tier.min}+ pts</span></div><div className="rank-progress-position"><small>POSIÇÃO GLOBAL</small><strong>{position === null ? '—' : `#${position}`}</strong></div></div>
  </section>;
  const earned = points - tier.min;
  const needed = nextTier.min - tier.min;
  return <section className="card rank-progress-card" aria-label="Progresso da sua patente">
    <div className="rank-progress-caption">SUA PATENTE</div>{guide}
    <div className="rank-progress-track-row">
      <div className="rank-progress-tier"><RankEmblem points={points}/><strong>{tier.name}</strong></div>
      <div className="rank-progress-center"><div className="rank-progress-bar" role="progressbar" aria-label={`Progresso para ${nextTier.name}`} aria-valuemin={0} aria-valuemax={needed} aria-valuenow={earned}><span style={{ width: `${earned / needed * 100}%` }}/></div><span>{tier.min} - {nextTier.min - 1}</span></div>
      <div className="rank-progress-tier"><RankEmblem points={nextTier.min}/><strong>{nextTier.name}</strong></div>
    </div>
  </section>;
}

function RankingRow({ player, ownUid, onOpen }: { player: RankedPlayer; ownUid: string; onOpen: (player: RankedPlayer) => void }) {
  const tier = rankTier(player.rankPoints);
  return <li className={player.uid === ownUid ? 'is-me' : ''}><button type="button" onClick={() => onOpen(player)} aria-label={`Abrir perfil de ${player.username}, posição ${player.position}, rank ${tier.name}, ${player.rankPoints} pontos`}>
    <span className="global-rank-position">#{player.position}</span>
    <Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl} borderStyle={player.passBorderStyle}/>
    <span className="global-rank-player"><strong className={`pass-name-${player.passNameStyle ?? 'none'}`}>@{player.username}</strong></span>
    <RankEmblem points={player.rankPoints}/>
    <strong className="global-rank-points">{player.rankPoints}</strong>
  </button></li>;
}

export default function GlobalRanking({ ownUid, ownPoints, lastClosedPrediction, today, refreshTick, onBattleSettled }: { ownUid: string; ownPoints: number; lastClosedPrediction: string | null; today: string; refreshTick: number; onBattleSettled?: () => void }) {
  const [players, setPlayers] = useState<RankedPlayer[]>([]);
  const [ownRank, setOwnRank] = useState<RankedPlayer | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const [selected, setSelected] = useState<RankedPlayer | null>(null);
  useEffect(() => {
    let current = true;
    setLoading(true); setError('');
    call<GlobalRankingPage>('getGlobalRankingPage')
      .then(({ players: rows, ownRank: own }) => { if (current) { setPlayers(rows); setOwnRank(own); } })
      .catch(cause => { if (current) setError(errorMessage(cause)); })
      .finally(() => { if (current) setLoading(false); });
    return () => { current = false; };
  }, [reload, refreshTick]);
  async function openProfile(player: RankedPlayer) {
    setSelected(player);
    try {
      const details = await call<PublicProfile | null>('getPublicProfile', { uid: player.uid });
      if (details) setSelected(current => current?.uid === player.uid ? { ...player, ...details } : current);
    } catch { /* The top-ten row remains available if profile details cannot load. */ }
    window.scrollTo({ top: 0, behavior: 'instant' });
  }
  if (selected) return <div className="public-profile-view">
    <button className="public-profile-back" onClick={() => setSelected(null)}><ArrowLeft size={18}/>Voltar ao Ranking</button>
    <div className="page-heading"><h1>Perfil público<span>.</span></h1></div>
    <ProfileOverview profile={selected} lastClosedPrediction={lastClosedPrediction} today={today}/>
  </div>;
  const ownPosition = ownRank?.position ?? players.find(player => player.uid === ownUid)?.position ?? null;
  return <div className="global-ranking-page">
    <RankProgress points={ownRank?.rankPoints ?? ownPoints} position={ownPosition}/>
    <DailyBattle onOpenProfile={uid=>{void call<PublicProfile | null>('getPublicProfile',{uid}).then(details=>{if(details){setSelected({...details,rankPoints:details.rankPoints ?? 0,position:details.rankPosition ?? 0});window.scrollTo({top:0,behavior:'instant'});}}).catch(cause=>setError(errorMessage(cause)));}} refreshTick={refreshTick + reload} onSettled={() => { setReload(value => value + 1); onBattleSettled?.(); }}/>
    <div className="page-heading"><div><h1>Ranking Global<span>.</span></h1></div><button className="icon-button" aria-label="Atualizar Ranking" aria-busy={loading} disabled={loading} onClick={() => setReload(value => value + 1)}><RefreshCw size={19} className={loading ? 'spin' : ''}/></button></div>
    <div className="card global-ranking-card" aria-busy={loading}>
      <div className="global-ranking-heading"><span>TOP 10 / JOGADOR</span><span>PONTOS</span></div>
      {error && <ErrorNotice message={error} retry={() => setReload(value => value + 1)}/>}
      <ol className="global-ranking-list">{players.map(player => <RankingRow key={player.uid} player={player} ownUid={ownUid} onOpen={player => void openProfile(player)}/>)}</ol>
      {ownRank && ownRank.position > 10 && <div className="global-ranking-own"><div className="global-ranking-own-label">SUA POSIÇÃO</div><ol className="global-ranking-list"><RankingRow player={ownRank} ownUid={ownUid} onOpen={player => void openProfile(player)}/></ol></div>}
      {loading && players.length === 0 && <div className="global-ranking-empty" role="status">Carregando jogadores…</div>}
      {!loading && !error && players.length === 0 && <div className="global-ranking-empty"><Shield size={28}/><p>Os jogadores aparecerão aqui quando entrarem no jogo.</p></div>}
    </div>
  </div>;
}
