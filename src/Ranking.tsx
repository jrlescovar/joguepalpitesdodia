import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { ArrowLeft, Check, Medal, RefreshCw, Trophy } from 'lucide-react';
import { call, errorMessage } from './backend';
import { seasonDaysRemaining } from './domain';
import type { Profile, PublicProfile } from './types';
import { Avatar, ErrorNotice } from './components';
import ProfileOverview from './ProfileOverview';

function RankingSkeleton() {
  return <div className="ranking-skeleton" role="status" aria-label="Carregando jogadores">
    {[1, 2, 3].map(row => <div className="ranking-skeleton-row" key={row} aria-hidden="true">
      <i className="skeleton-avatar"/><i className="skeleton-line"/><i className="skeleton-score"/>
    </div>)}
  </div>;
}

export default function Ranking({ profile, serverTime, lastClosedPrediction, onOpenOwnProfile, restoreScrollY, onScrollRestored }: { profile: Profile; serverTime: number; lastClosedPrediction: string | null; onOpenOwnProfile: () => void; restoreScrollY: number | null; onScrollRestored: () => void }) {
  const [players, setPlayers] = useState<PublicProfile[]>([]);
  const [playersLoading, setPlayersLoading] = useState(true);
  const [rankLoading, setRankLoading] = useState(true);
  const [error, setError] = useState('');
  const [rankError, setRankError] = useState('');
  const [rank, setRank] = useState<number | null>(null);
  const [reload, setReload] = useState(0);
  const [now, setNow] = useState(() => new Date(serverTime));
  const [selected, setSelected] = useState<{ player: PublicProfile; position: number } | null>(null);
  const rankingScroll = useRef(0);
  const viewReady = useRef(false);
  const lastSelectedUid = useRef<string | null>(null);
  const rowButtons = useRef(new Map<string, HTMLButtonElement>());

  useLayoutEffect(() => {
    if (!viewReady.current) { viewReady.current = true; return; }
    window.scrollTo({ top: selected ? 0 : rankingScroll.current, behavior: 'instant' });
    if (!selected && lastSelectedUid.current) rowButtons.current.get(lastSelectedUid.current)?.focus({ preventScroll: true });
  }, [selected]);

  useLayoutEffect(() => {
    if (restoreScrollY === null || playersLoading) return;
    window.scrollTo({ top: restoreScrollY, behavior: 'instant' });
    rowButtons.current.get(profile.uid)?.focus({ preventScroll: true });
    onScrollRestored();
  }, [restoreScrollY, playersLoading, players]);

  useEffect(() => {
    if (!selected) return;
    let active = true;
    call<PublicProfile|null>('getPublicProfile',{uid:selected.player.uid}).then(player => {
      if (active && player) setSelected(current => current?.player.uid === player.uid
        ? { ...current, player } : current);
    }).catch(() => {});
    return () => { active = false; };
  }, [selected?.player.uid]);

  useEffect(() => {
    const offset = serverTime - Date.now();
    setNow(new Date(Date.now() + offset));
    const timer = window.setInterval(() => setNow(new Date(Date.now() + offset)), 60000);
    return () => clearInterval(timer);
  }, [serverTime]);

  useEffect(() => {
    let active = true;
    setPlayersLoading(true);
    setRankLoading(true);
    setError('');
    setRankError('');

    call<PublicProfile[]>('getRankingTop10')
      .then(result => {
        if (active) setPlayers(result);
      })
      .catch(cause => { if (active) setError(errorMessage(cause)); })
      .finally(() => { if (active) setPlayersLoading(false); });

    call<{ position: number | null; change?: number }>('getMyRank')
      .then(result => { if (active) setRank(result.position); })
      .catch(cause => { if (active) setRankError(errorMessage(cause)); })
      .finally(() => { if (active) setRankLoading(false); });

    return () => { active = false; };
  }, [profile.uid, profile.green, reload]);

  const seasonDays = seasonDaysRemaining(now);
  const seasonEnded = now.getTime() >= Date.parse('2026-10-31T02:59:59Z');
  const refreshing = playersLoading || rankLoading;
  const openPlayer = (player: PublicProfile, position: number) => {
    if (player.uid === profile.uid) { onOpenOwnProfile(); return; }
    rankingScroll.current = window.scrollY;
    lastSelectedUid.current = player.uid;
    setSelected({ player, position });
  };
  const podium = [players[1], players[0], players[2]]
    .filter(Boolean)
    .map(player => ({ player, position: players.indexOf(player) + 1 }));

  if (selected) return <div className="public-profile-view">
    <button className="public-profile-back" onClick={() => setSelected(null)}><ArrowLeft size={18}/>Voltar ao ranking</button>
    <div className="page-heading"><div><div className="eyebrow">JOGADOR DO RANKING</div><h1>Perfil público<span>.</span></h1></div></div>
    <ProfileOverview profile={selected.player} lastClosedPrediction={lastClosedPrediction}/>
  </div>;

  return <>
    <div className="page-heading">
      <div>
        <h1>Ranking Edição Beta</h1>
      </div>
      <button className="icon-button" aria-label={refreshing ? 'Atualizando ranking' : 'Atualizar ranking'} aria-busy={refreshing} onClick={() => setReload(value => value + 1)} disabled={refreshing}>
        <RefreshCw size={19} className={refreshing ? 'spin' : ''}/>
      </button>
    </div>
    <div className="ranking-summary">
      <div>
        <div className="card my-rank" aria-busy={rankLoading}>
          <span className="eyebrow">SEU LUGAR NO JOGO</span><Trophy size={32}/>
          <strong>{rank ? `#${rank}` : rankLoading ? '···' : '—'}</strong>
          <span className="muted text-sm">{rankError ? 'Posição indisponível' : 'Sua posição global'}</span>
        </div>
        {rankError && <ErrorNotice message={rankError} retry={() => setReload(value => value + 1)}/>}
      </div>
      <section className="card season-card season-card-inline" aria-label="Temporada e premiação">
        <div className="season-row"><span>{seasonEnded ? 'Temporada' : 'Termina em'}</span><strong>{seasonEnded ? 'Encerrada' : seasonDays === 0 ? 'Hoje' : `${seasonDays} ${seasonDays === 1 ? 'dia' : 'dias'}`}</strong></div>
        <div className="season-row prize-row"><span>Premiação</span><strong>R$ 100,00</strong></div>
      </section>
    </div>
    {!playersLoading && podium.length > 0 && <section className="season-podium" aria-label="Três primeiros da temporada">
      <div className="podium-grid">{podium.map(({ player, position }) => <button ref={element => { if (element) rowButtons.current.set(player.uid, element); else rowButtons.current.delete(player.uid); }} key={player.uid} className={`podium-place place-${position}`} onClick={() => openPlayer(player, position)} aria-label={`Abrir perfil de ${player.username}, posição ${position}`}>
        <span className="podium-medal"><Medal size={21}/>#{position}</span>
        <Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl}/><strong>@{player.username}</strong><small>{player.green}</small>
      </button>)}</div>
    </section>}
    <div className="card ranking-card ranking-continuation" aria-busy={playersLoading}>
        <div className="ranking-table-heading"><span>POSIÇÃO / JOGADOR</span><span>GREENS</span></div>
        {error && <ErrorNotice message={error} retry={() => setReload(value => value + 1)}/>}
        <ol className="ranking-list">
          {players.slice(3).map((player, index) => { const position = index + 4; return <li key={player.uid} className={player.uid === profile.uid ? 'is-me' : ''}><button ref={element => { if (element) rowButtons.current.set(player.uid, element); else rowButtons.current.delete(player.uid); }} className="rank-player-button" aria-label={`Abrir perfil de ${player.username}, posição ${position}`} onClick={() => openPlayer(player, position)}>
            <span className={`rank-number rank-${position}`}>#{position}</span>
            <Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl}/>
            <div className="rank-name"><strong>@{player.username}{player.uid === profile.uid && <small>VOCÊ</small>}</strong></div>
            <strong className="rank-greens">{player.green}<Check size={13}/></strong>
          </button></li>; })}
        </ol>
        {playersLoading && players.length === 0 && <RankingSkeleton/>}
        {!playersLoading && !error && players.length === 0 && <div className="daily-empty"><Trophy size={34}/><h2>O ranking começa aqui.</h2><p>Os jogadores aparecerão assim que criarem seus perfis.</p></div>}
    </div>
  </>;
}
