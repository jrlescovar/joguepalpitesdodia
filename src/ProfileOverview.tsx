import { Check, Target, X } from 'lucide-react';
import { greenMedalProgress, hitRate, visibleDaily } from './domain';
import { Avatar, XpBar } from './components';
import RankEmblem from './RankEmblem';
import SupporterEmblem from './SupporterEmblem';
import GreenMedalEmblem from './GreenMedalEmblem';
import BetaTesterEmblem from './BetaTesterEmblem';
import type { Profile, PublicProfile } from './types';

type OverviewProfile = Profile | PublicProfile;

function Stat({ icon: Icon, label, value, tone, hint }: { icon: typeof Check; label: string; value: number | string; tone: string; hint?: string }) {
  return <div className={`card stat-card ${tone}`}><span><Icon size={17}/>{label}</span><strong>{value}</strong>{hint&&<small>{hint}</small>}</div>;
}

export default function ProfileOverview({ profile, lastClosedPrediction, showBalance = false, supporterActive = false }: {
  profile: OverviewProfile;
  lastClosedPrediction: string | null;
  showBalance?: boolean;
  supporterActive?: boolean;
}) {
  const numberOrDash = (value: number | undefined) => typeof value === 'number' ? value : '—';
  const daily = typeof profile.dailyStreakCurrent === 'number'
    ? visibleDaily(profile.dailyStreakCurrent, profile.lastPlayedPrediction, lastClosedPrediction)
    : '—';
  const settled = typeof profile.red === 'number' ? profile.green + profile.red : null;
  const rate = hitRate(profile.green, profile.red);
  const medal = greenMedalProgress(profile.green);
  const publicSupporterActive = 'supporterActive' in profile && profile.supporterActive === true;
  const hasSupporterEmblem = supporterActive || publicSupporterActive ||
    (profile.passBorderStyle !== undefined && profile.passBorderStyle !== 'none') ||
    (profile.passNameStyle !== undefined && profile.passNameStyle !== 'none');
  const rows: Array<[string, number | string]> = [
    ['Greens consecutivos', numberOrDash(profile.greenStreakCurrent)],
    ['Maior sequência de greens', numberOrDash(profile.greenStreakMax)],
    ['Dias consecutivos', daily],
    ['Maior sequência de dias consecutivos', numberOrDash(profile.dailyStreakMax)],
  ];
  if (showBalance && 'balance' in profile) rows.push(['Saldo', `R$ ${profile.balance.toLocaleString('pt-BR')}`]);
  return <div className="profile-overview"><div className="profile-layout">
    <section className="card profile-identity">
      {typeof profile.rankPoints === 'number' && <div className="profile-rank-badge"><RankEmblem points={profile.rankPoints}/><strong>{profile.rankPoints}</strong></div>}
      <Avatar name={profile.username} color={profile.avatarColor} imageUrl={profile.avatarUrl} borderStyle={profile.passBorderStyle} large/>
      <h2 className={`pass-name-${profile.passNameStyle ?? 'none'}`}>@{profile.username}</h2>
      <span className="muted text-sm">#{profile.playerId}</span>
      {typeof profile.level === 'number' && typeof profile.xp === 'number'
        ? <><div className="profile-level-mark">{hasSupporterEmblem&&<SupporterEmblem className="profile-supporter-emblem"/>}<span className="level-badge">Nível {profile.level}</span></div><XpBar profile={{ level: profile.level, xp: profile.xp }} showRemaining={false}/></>
        : <span className="muted text-sm profile-data-pending">Progresso indisponível no momento</span>}
    </section>
    <section>
      <div className="score-grid profile-score-grid"><Stat icon={Check} label="Greens" value={profile.green} tone="green"/><Stat icon={X} label="Reds" value={numberOrDash(profile.red)} tone="red"/><Stat icon={Target} label="Taxa de acerto" value={rate===null?'—':`${rate}%`} tone="accuracy" hint={settled===null?'Dados indisponíveis':settled===0?'Sem resultados':`${profile.green} de ${settled}`}/></div>
      <div className="card profile-stats">{rows.map(([label, value]) => <div className="streak-row" key={label}><span>{label}</span><strong>{value}</strong></div>)}</div>
    </section>
  </div><section className="card achievements-card" aria-label="Medalhas e marcas">
    <div className="achievements-heading"><span className="eyebrow">MEDALHAS E MARCAS</span></div>
    <div className="medals-grid">
      {medal.level>0&&<div className="medal-tile" role="img" aria-label={`Colecionador de Greens, nível ${medal.level}`}>
        <span className="medal-level">Nível {medal.level}</span>
        <GreenMedalEmblem level={medal.level}/>
        <strong className="medal-name">Colecionador de Greens</strong>
      </div>}
      {profile.betaTester&&<div className="medal-tile" role="img" aria-label="Medalha Beta Tester">
        <span className="medal-level">Edição Beta</span>
        <BetaTesterEmblem/>
        <strong className="medal-name">Beta Tester</strong>
      </div>}
      {medal.level===0&&!profile.betaTester&&<div className="achievements-empty">Suas medalhas aparecerão aqui.</div>}
    </div>
  </section></div>;
}
