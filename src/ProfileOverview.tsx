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
import type { Profile, PublicProfile } from './types';

type OverviewProfile = Profile | PublicProfile;
type BattleStats = { wins: number; losses: number; draws: number };
type OverviewMeta = { globalPosition: number; battleStats: BattleStats };

function Stat({ icon: Icon, label, value, tone, hint }: { icon: typeof Check; label: string; value: number | string; tone: string; hint?: string }) {
  return <div className={`card stat-card ${tone}`}><span><Icon size={17}/>{label}</span><strong>{value}</strong>{hint&&<small>{hint}</small>}</div>;
}

export default function ProfileOverview({ profile, lastClosedPrediction, today, showBalance = false, supporterActive = false, refreshTick = 0 }: {
  profile: OverviewProfile;
  lastClosedPrediction: string | null;
  today: string;
  showBalance?: boolean;
  supporterActive?: boolean;
  refreshTick?: number;
}) {
  const [globalPosition, setGlobalPosition] = useState<number | null>(null);
  const [battleStats, setBattleStats] = useState<BattleStats | null>(null);
  useEffect(() => {
    let active = true;
    setGlobalPosition(null);
    setBattleStats(null);
    void call<OverviewMeta | null>('getProfileOverviewMeta', { uid: profile.uid })
      .then(meta => {
        if (!active) return;
        setGlobalPosition(typeof meta?.globalPosition === 'number' ? meta.globalPosition : null);
        setBattleStats(meta?.battleStats ?? null);
      })
      .catch(() => { if (active) { setGlobalPosition(null); setBattleStats(null); } });
    return () => { active = false; };
  }, [profile.uid, profile.rankPoints, refreshTick]);
  const numberOrDash = (value: number | undefined) => typeof value === 'number' ? value : '—';
  const daily = typeof profile.dailyStreakCurrent === 'number'
    ? visibleDaily(profile.dailyStreakCurrent, profile.lastPlayedPrediction, lastClosedPrediction, today)
    : '—';
  const rate = hitRate(profile.green, profile.red);
  const battleTotal = battleStats ? battleStats.wins + battleStats.losses + battleStats.draws : 0;
  const battleWinRate = battleStats && battleTotal > 0 ? `${Math.round(100 * battleStats.wins / battleTotal)}%` : battleStats ? '0%' : '—';
  const medal = greenMedalProgress(profile.green);
  const battleMedal = battleStats ? battleMedalProgress(battleStats.wins) : null;
  const publicSupporterActive = 'supporterActive' in profile && profile.supporterActive === true;
  const hasSupporterEmblem = supporterActive || publicSupporterActive;
  const rows: Array<[string, number | string]> = [
    ['Greens consecutivos', numberOrDash(profile.greenStreakCurrent)],
    ['Maior sequência de greens', numberOrDash(profile.greenStreakMax)],
    ['Dias consecutivos', daily],
  ];
  if (showBalance && 'balance' in profile) rows.push(['Saldo', `R$ ${profile.balance.toLocaleString('pt-BR')}`]);
  return <div className="profile-overview"><div className="profile-layout">
    <section className="card profile-identity">
      {typeof profile.rankPoints === 'number' && <div className="profile-rank-badge"><RankEmblem points={profile.rankPoints}/><strong>{profile.rankPoints} pts</strong>{globalPosition !== null && <span className="profile-rank-global" aria-label={`Posição global ${globalPosition}`}>#{globalPosition}</span>}</div>}
      <Avatar name={profile.username} color={profile.avatarColor} imageUrl={profile.avatarUrl} borderStyle={profile.passBorderStyle} large/>
      <h2 className={`pass-name-${profile.passNameStyle ?? 'none'} username-font-${profile.usernameFont ?? 'normal'}`}>@{profile.username}</h2>
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
  </div><section className="profile-battle-stats" aria-label="Estatísticas da Batalha do Dia">
    <h2>Batalha do Dia</h2>
    <div className="score-grid profile-score-grid"><Stat icon={Trophy} label="Vitórias" value={battleStats?.wins ?? '—'} tone="battle-wins"/><Stat icon={X} label="Derrotas" value={battleStats?.losses ?? '—'} tone="red"/><Stat icon={Target} label="% de vitória" value={battleWinRate} tone="accuracy"/></div>
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
      {medal.level===0&&!(battleMedal&&battleMedal.level>0)&&!profile.betaTester&&<div className="achievements-empty">Suas medalhas aparecerão aqui.</div>}
    </div>
  </section></div>;
}
