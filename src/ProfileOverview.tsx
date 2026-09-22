import { Award, Check, X } from 'lucide-react';
import { visibleDaily } from './domain';
import { Avatar, XpBar } from './components';
import type { Profile, PublicProfile } from './types';

type OverviewProfile = Profile | PublicProfile;

function Stat({ icon: Icon, label, value, tone }: { icon: typeof Check; label: string; value: number | string; tone: string }) {
  return <div className={`card stat-card ${tone}`}><span><Icon size={17}/>{label}</span><strong>{value}</strong></div>;
}

export default function ProfileOverview({ profile, lastClosedPrediction, showBalance = false }: {
  profile: OverviewProfile;
  lastClosedPrediction: string | null;
  showBalance?: boolean;
}) {
  const numberOrDash = (value: number | undefined) => typeof value === 'number' ? value : '—';
  const daily = typeof profile.dailyStreakCurrent === 'number'
    ? visibleDaily(profile.dailyStreakCurrent, profile.lastPlayedPrediction, lastClosedPrediction)
    : '—';
  const rows: Array<[string, number | string]> = [
    ['Greens consecutivos', numberOrDash(profile.greenStreakCurrent)],
    ['Maior sequência de greens', numberOrDash(profile.greenStreakMax)],
    ['Apostas consecutivas', daily],
    ['Maior sequência de apostas', numberOrDash(profile.dailyStreakMax)],
  ];
  if (showBalance && 'balance' in profile) rows.push(['Saldo', `R$ ${profile.balance.toLocaleString('pt-BR')}`]);
  return <div className="profile-overview"><div className="profile-layout">
    <section className="card profile-identity">
      <Avatar name={profile.username} color={profile.avatarColor} imageUrl={profile.avatarUrl} large/>
      <h2>@{profile.username}</h2>
      <span className="muted text-sm">#{profile.playerId}</span>
      {typeof profile.level === 'number' && typeof profile.xp === 'number'
        ? <><span className="level-badge">Nível {profile.level}</span><XpBar profile={{ level: profile.level, xp: profile.xp }} showRemaining={false}/></>
        : <span className="muted text-sm profile-data-pending">Progresso indisponível no momento</span>}
    </section>
    <section>
      <div className="score-grid"><Stat icon={Check} label="Greens" value={profile.green} tone="green"/><Stat icon={X} label="Reds" value={numberOrDash(profile.red)} tone="red"/></div>
      <div className="card profile-stats">{rows.map(([label, value]) => <div className="streak-row" key={label}><span>{label}</span><strong>{value}</strong></div>)}</div>
    </section>
  </div><section className="card achievements-card" aria-label="Medalhas e marcas">
    <div className="achievements-heading"><span className="eyebrow">MEDALHAS E MARCAS</span><Award size={22}/></div>
    <div className="achievements-empty"><span>Suas conquistas aparecerão aqui.</span></div>
  </section></div>;
}
