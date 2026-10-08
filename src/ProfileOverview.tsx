import UsernameText from './UsernameText';
import ProfileBattle from './ProfileBattle';
import ProfileAdminPanel from './ProfileAdminPanel';
import { useEffect, useState } from 'react';
import { Check, Target, Trophy, X } from 'lucide-react';
import { call } from './backend';
import { battleMedalProgress, greenMedalProgress, hitRate, visibleDaily } from './domain';
import { Avatar, XpBar } from './components';
import RankEmblem from './RankEmblem';
import SupporterEmblem from './SupporterEmblem';
import GreenMedalEmblem from './GreenMedalEmblem';
import BattleMedalEmblem from './BattleMedalEmblem';
import BetaTesterEmblem from './BetaTesterEmblem';
import ArenaMedalEmblem from './ArenaMedalEmblem';
import ArenaChampionEmblem from './ArenaChampionEmblem';
import SupporterMedalEmblem from './SupporterMedalEmblem';
import TournamentMedalEmblem from './TournamentMedalEmblem';
import './supporter.css';
import type { Profile, PublicProfile } from './types';
import './halloween.css';

type OverviewProfile = Profile | PublicProfile;
type BattleStats = { wins: number; losses: number; draws: number };
type OverviewMeta = { globalPosition: number; battleStats: BattleStats; arenaWins: number; arenaChampionships?:number; supporterMonths: number; finishingTournamentWins?: number };

function Stat({ icon: Icon, label, value, tone, hint }: { icon: typeof Check; label: string; value: number | string; tone: string; hint?: string }) {
  return <div className={`card stat-card ${tone}`}><span><Icon size={17}/>{label}</span><strong>{value}</strong>{hint&&<small>{hint}</small>}</div>;
}

export default function ProfileOverview({ profile, lastClosedPrediction, today, supporterActive = false, refreshTick = 0, onOpenProfile }: {
  profile: OverviewProfile;
  lastClosedPrediction: string | null;
  today: string;
  supporterActive?: boolean;
  refreshTick?: number;
  onOpenProfile?: (uid:string)=>void;
}) {
  const [globalPosition, setGlobalPosition] = useState<number | null>(null);
  const [battleStats, setBattleStats] = useState<BattleStats | null>(null);
  const [arenaWins, setArenaWins] = useState(0);
  const [arenaChampionships,setArenaChampionships]=useState(0);
  const [supporterMonths, setSupporterMonths] = useState(0);
  const [finishingTournamentWins, setFinishingTournamentWins] = useState(0);
  useEffect(() => {
    let active = true;
    setGlobalPosition(null);
    setBattleStats(null);
    setArenaWins(0);
    setArenaChampionships(0);
    setSupporterMonths(0);
    setFinishingTournamentWins(0);
    void call<OverviewMeta | null>('getProfileOverviewMeta', { uid: profile.uid })
      .then(meta => {
        if (!active) return;
        setGlobalPosition(typeof meta?.globalPosition === 'number' ? meta.globalPosition : null);
        setBattleStats(meta?.battleStats ?? null);
        setArenaWins(meta?.arenaWins ?? 0);
        setArenaChampionships(meta?.arenaChampionships ?? 0);
        setSupporterMonths(meta?.supporterMonths ?? 0);
        setFinishingTournamentWins(meta?.finishingTournamentWins ?? 0);
      })
      .catch(() => { if (active) { setGlobalPosition(null); setBattleStats(null); setArenaWins(0); setArenaChampionships(0); setSupporterMonths(0); setFinishingTournamentWins(0); } });
    return () => { active = false; };
  }, [profile.uid, profile.rankPoints, refreshTick]);
  const numberOrDash = (value: number | undefined) => typeof value === 'number' ? value : '—';
  const daily = typeof profile.dailyStreakCurrent === 'number'
    ? visibleDaily(profile.dailyStreakCurrent, profile.lastPlayedPrediction, lastClosedPrediction, today)
    : '—';
  const rate = hitRate(profile.green, profile.red);
  const decidedBattles = battleStats ? battleStats.wins + battleStats.losses : 0;
  const battleWinRate = battleStats && decidedBattles > 0 ? `${Math.round(100 * battleStats.wins / decidedBattles)}%` : battleStats ? '0%' : '—';
  const medal = greenMedalProgress(profile.green);
  const battleMedal = battleStats ? battleMedalProgress(battleStats.wins) : null;
  const publicSupporterActive = 'supporterActive' in profile && profile.supporterActive === true;
  const hasSupporterEmblem = supporterActive || publicSupporterActive;
  const showArenaMedal = arenaWins > 0;
  const rows: Array<[string, number | string]> = [
    ['Greens consecutivos', numberOrDash(profile.greenStreakCurrent)],
    ['Maior sequência de greens', numberOrDash(profile.greenStreakMax)],
    ['Reds consecutivos', numberOrDash(profile.redStreakCurrent)],
    ['Maior sequência de reds', numberOrDash(profile.redStreakMax)],
    ['Dias consecutivos', daily],
  ];
  return <div className="profile-overview"><div className="profile-layout">
    <section className="card profile-identity">
      {typeof profile.rankPoints === 'number' && <div className="profile-rank-badge"><RankEmblem points={profile.rankPoints}/><strong>{profile.rankPoints} pts</strong>{globalPosition !== null && <span className="profile-rank-global" aria-label={`Posição global ${globalPosition}`}>#{globalPosition}</span>}</div>}
      <Avatar name={profile.username} color={profile.avatarColor} imageUrl={profile.avatarUrl} borderStyle={profile.passBorderStyle} large/>
      <h2 className={`pass-name-${profile.passNameStyle ?? 'none'}`}><UsernameText name={profile.username} font={profile.usernameFont}/></h2>
      <span className="muted text-sm">#{profile.playerId}</span>
      {typeof profile.level === 'number' && typeof profile.xp === 'number'
        ? <><div className="profile-level-mark">{hasSupporterEmblem&&<SupporterEmblem className="profile-supporter-emblem"/>}<span className="level-badge">Nível {profile.level}</span></div><XpBar profile={{ level: profile.level, xp: profile.xp }} showRemaining={false}/></>
        : <span className="muted text-sm profile-data-pending">Progresso indisponível no momento</span>}
    </section>
    <section className="profile-picks-stats">
      <h2>Palpites do Dia</h2>
      <div className="score-grid profile-score-grid"><Stat icon={Check} label="Greens" value={profile.green} tone="green"/><Stat icon={X} label="Reds" value={numberOrDash(profile.red)} tone="red"/><Stat icon={Target} label="% de Acerto" value={rate===null?'—':`${rate}%`} tone="accuracy"/></div>
      <div className="card profile-stats">{rows.map(([label, value]) => <div className="streak-row" key={label}><span>{label}</span><strong>{value}</strong></div>)}</div>
    </section>
  </div><section className="profile-battle-stats" aria-label="Estatísticas do Confronto do Dia">
    <h2>Confronto do Dia</h2>
    <div className="score-grid profile-score-grid"><Stat icon={Trophy} label="Vitórias" value={battleStats?.wins ?? '—'} tone="battle-wins"/><Stat icon={X} label="Derrotas" value={battleStats?.losses ?? '—'} tone="red"/><Stat icon={Target} label="% de vitória" value={battleWinRate} tone="accuracy"/></div>
    <ProfileBattle key={profile.uid} uid={profile.uid} refreshTick={refreshTick} onOpenProfile={onOpenProfile}/>
  </section><section className="card achievements-card" aria-label="Medalhas e marcas">
    <div className="achievements-heading"><span className="eyebrow">MEDALHAS E MARCAS</span></div>
    <div className="medals-grid">
      {medal.level>0&&<div className="medal-tile" role="img" aria-label={`Colecionador de Greens, nível ${medal.level}`}>
        <span className="medal-level">Nível {medal.level}</span>
        <GreenMedalEmblem level={medal.level}/>
        <strong className="medal-name">Colecionador de Greens</strong>
      </div>}
      {battleMedal&&battleMedal.level>0&&<div className="medal-tile" role="img" aria-label={`Colecionador de Vitórias, nível ${battleMedal.level}`}>
        <span className="medal-level">Nível {battleMedal.level}</span>
        <BattleMedalEmblem level={battleMedal.level}/>
        <strong className="medal-name">Colecionador de Vitórias</strong>
      </div>}
      {profile.betaTester&&<div className="medal-tile" role="img" aria-label="Medalha Beta Tester">
        <span className="medal-level">Edição Beta</span>
        <BetaTesterEmblem/>
        <strong className="medal-name">Beta Tester</strong>
      </div>}
      {showArenaMedal&&<div className="medal-tile arena-winner-medal-tile" role="img" aria-label={`Vencedor Dia Arena, ${arenaWins} ${arenaWins===1?'vitória':'vitórias'}`}>
        <span className="medal-level">Vencedor Dia Arena</span>
        <ArenaMedalEmblem/>
        <strong className="medal-name">{arenaWins}</strong>
      </div>}
      {arenaChampionships>0&&<div className="medal-tile arena-winner-medal-tile" role="img" aria-label={`Campeão da Arena, ${arenaChampionships} ${arenaChampionships===1?'título':'títulos'}`}><span className="medal-level">Campeão da Arena</span><ArenaChampionEmblem/><strong className="medal-name">{arenaChampionships}</strong></div>}
      {finishingTournamentWins>0&&<div className="medal-tile tournament-medal-tile" role="img" aria-label={`Torneio Finalização, ${finishingTournamentWins} ${finishingTournamentWins===1?'vitória':'vitórias'}`}>
        <span className="medal-level">Campeão: {finishingTournamentWins}x</span>
        <TournamentMedalEmblem/>
        <strong className="medal-name">Torneio<br/>Finalização</strong>
      </div>}
      {supporterMonths>0&&<div className="medal-tile supporter-medal-tile" role="img" aria-label={`Apoiador, ${supporterMonths} ${supporterMonths===1?'mês':'meses'} de Apoiador`}>
        <span className="medal-level">Apoiador</span>
        <SupporterMedalEmblem/>
        <strong className="medal-name">{supporterMonths} {supporterMonths===1?'mês':'meses'}</strong>
      </div>}
      {medal.level===0&&!(battleMedal&&battleMedal.level>0)&&!profile.betaTester&&!showArenaMedal&&arenaChampionships===0&&supporterMonths===0&&finishingTournamentWins===0&&<div className="achievements-empty">Suas medalhas aparecerão aqui.</div>}
    </div>
  </section><div className="profile-admin-footer"><ProfileAdminPanel key={profile.uid} playerId={profile.playerId}/></div></div>;
}

