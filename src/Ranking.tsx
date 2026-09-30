import UsernameText from './UsernameText';
import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { ArrowLeft, Check, Medal, RefreshCw, Trophy } from 'lucide-react';
import { call, errorMessage } from './backend';
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

type TournamentRankingPage = { players: PublicProfile[]; ownRank: { position: number | null; change?: number } | null };

export default function Ranking({ profile, lastClosedPrediction, today, refreshTick, onOpenOwnProfile, restoreScrollY, onScrollRestored }: { profile: Profile; serverTime: number; lastClosedPrediction: string | null; today: string; refreshTick: number; onOpenOwnProfile: () => void; restoreScrollY: number | null; onScrollRestored: () => void }) {
  const [players, setPlayers] = useState<PublicProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [rank, setRank] = useState<number | null>(null);
  const [reload, setReload] = useState(0);
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
    if (restoreScrollY === null || loading) return;
    window.scrollTo({ top: restoreScrollY, behavior: 'instant' });
    rowButtons.current.get(profile.uid)?.focus({ preventScroll: true });
    onScrollRestored();
  }, [restoreScrollY, loading, players]);

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
    let active = true;
    setLoading(true);
    setError('');

    call<TournamentRankingPage>('getTournamentRankingPage')
      .then(result => { if (active) { setPlayers(result.players); setRank(result.ownRank?.position ?? null); } })
      .catch(cause => { if (active) setError(errorMessage(cause)); })
      .finally(() => { if (active) setLoading(false); });

    return () => { active = false; };
  }, [profile.uid, profile.green, reload, refreshTick]);

  const refreshing = loading;
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
    <button className="public-profile-back" onClick={() => setSelected(null)}><ArrowLeft size={18}/>Voltar ao Torneio</button>
    <div className="page-heading"><div><h1>Perfil público<span>.</span></h1></div></div>
    <ProfileOverview profile={selected.player} lastClosedPrediction={lastClosedPrediction} today={today}/>
  </div>;

  return <>
    <div className="tournament-top">
    <div className="page-heading">
      <div>
        <h1>Torneio Edição Beta<span>.</span></h1>
      </div>
      <button className="icon-button" aria-label={refreshing ? 'Atualizando Torneio' : 'Atualizar Torneio'} aria-busy={refreshing} onClick={() => setReload(value => value + 1)} disabled={refreshing}>
        <RefreshCw size={19} className={refreshing ? 'spin' : ''}/>
      </button>
    </div>
    <div className="ranking-summary">
      <div>
        <div className="card my-rank" aria-busy={loading}>
          <span className="eyebrow">SEU LUGAR NO JOGO</span><Trophy size={32}/>
          <strong>{rank ? `#${rank}` : loading ? '···' : '—'}</strong>
          <span className="muted text-sm">{error ? 'Posição indisponível' : 'Sua posição global'}</span>
        </div>
      </div>
    </div>
    </div>
    {podium.length > 0 && <section className="season-podium" aria-label="Três primeiros da temporada">
      <div className="podium-grid">{podium.map(({ player, position }) => <button ref={element => { if (element) rowButtons.current.set(player.uid, element); else rowButtons.current.delete(player.uid); }} key={player.uid} className={`podium-place place-${position}`} onClick={() => openPlayer(player, position)} aria-label={`Abrir perfil de ${player.username}, posição ${position}`}>
        <span className="podium-medal"><Medal size={21}/>#{position}</span>
        <Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl} borderStyle={player.passBorderStyle}/><strong><UsernameText name={player.username} font={player.usernameFont} className={`pass-name-${player.passNameStyle ?? 'none'}`}/></strong><small>{player.green}</small>
      </button>)}</div>
    </section>}
    <div className="card ranking-card ranking-continuation" aria-busy={loading}>
        <div className="ranking-table-heading"><span>POSIÇÃO / JOGADOR</span><span>GREENS</span></div>
        {error && <ErrorNotice message={error} retry={() => setReload(value => value + 1)}/>}
        <ol className="ranking-list">
          {players.slice(3).map((player, index) => { const position = index + 4; return <li key={player.uid} className={player.uid === profile.uid ? 'is-me' : ''}><button ref={element => { if (element) rowButtons.current.set(player.uid, element); else rowButtons.current.delete(player.uid); }} className="rank-player-button" aria-label={`Abrir perfil de ${player.username}, posição ${position}`} onClick={() => openPlayer(player, position)}>
            <span className={`rank-number rank-${position}`}>#{position}</span>
            <Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl} borderStyle={player.passBorderStyle}/>
            <div className="rank-name"><strong><UsernameText name={player.username} font={player.usernameFont} className={`pass-name-${player.passNameStyle ?? 'none'}`}/></strong></div>
            <strong className="rank-greens">{player.green}<Check size={13}/></strong>
          </button></li>; })}
        </ol>
        {loading && players.length === 0 && <RankingSkeleton/>}
        {!loading && !error && players.length === 0 && <div className="daily-empty"><Trophy size={34}/><h2>O torneio começa aqui.</h2><p>Os jogadores aparecerão assim que criarem seus perfis.</p></div>}
    </div>
  </>;
}
