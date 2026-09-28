import { rankTier } from './rankTiers';

export default function RankEmblem({ points }: { points: number }) {
  const tier = rankTier(points);
  return <span className={`rank-emblem rank-emblem-${tier.key}`} role="img" aria-label={`Rank ${tier.name}`}>
    <svg viewBox="0 0 64 64" fill="none" aria-hidden="true">
      {tier.key === 'bronze' && <>
        <path className="rank-ghost" d="M32 3 52 15v27L32 60 12 42V15z"/>
        <path className="rank-stroke" d="M32 3 52 15v27L32 60 12 42V15z"/>
        <path className="rank-thin" d="M32 11 45 19v20L32 50 19 39V19z"/>
        <path className="rank-fill" d="m32 16 7 15-7 16-7-16z"/>
        <path className="rank-stroke" d="m25 31-9-8m23 8 9-8"/>
      </>}
      {tier.key === 'silver' && <>
        <path className="rank-ghost" d="M32 4 56 19 48 49 32 60 16 49 8 19z"/>
        <path className="rank-stroke" d="M32 4 56 19 48 49 32 60 16 49 8 19z"/>
        <path className="rank-stroke" d="M32 13v36M13 23l19 12 19-12M15 32l17 10 17-10"/>
        <path className="rank-thin" d="m22 18 10-6 10 6"/>
      </>}
      {tier.key === 'gold' && <>
        <path className="rank-ghost" d="M32 3 53 12v28L32 61 11 40V12z"/>
        <path className="rank-stroke" d="M32 3 53 12v28L32 61 11 40V12z"/>
        <path className="rank-thin" d="M32 11 46 18v19L32 51 18 37V18z"/>
        <path className="rank-stroke" d="m20 22 12 8 12-8m-24 9 12 8 12-8m-24 9 12 8 12-8"/>
        <path className="rank-thin" d="M32 16v32"/>
      </>}
      {tier.key === 'platinum' && <>
        <path className="rank-ghost" d="M23 5h18l17 27-17 27H23L6 32z"/>
        <path className="rank-stroke" d="M23 5h18l17 27-17 27H23L6 32z"/>
        <path className="rank-thin" d="M25 13h14l12 19-12 19H25L13 32z"/>
        <path className="rank-stroke" d="M32 17v30M17 32h30m-25-10 20 20m0-20L22 42"/>
      </>}
      {tier.key === 'diamond' && <>
        <path className="rank-ghost" d="M18 9h28l14 17-28 32L4 26z"/>
        <path className="rank-stroke" d="M18 9h28l14 17-28 32L4 26z"/>
        <path className="rank-thin" d="M4 26h56M18 9l-5 17 19 32 19-32-5-17M18 9l14 17L46 9"/>
      </>}
      {tier.key === 'emerald' && <>
        <path className="rank-ghost" d="M32 3 53 15v27L32 61 11 42V15z"/>
        <path className="rank-stroke" d="M32 3 53 15v27L32 61 11 42V15z"/>
        <path className="rank-thin" d="M32 10 47 19v20L32 52 17 39V19z"/>
        <path className="rank-stroke" d="M25 17h14l7 9v14l-7 9H25l-7-9V26z"/>
        <path className="rank-thin" d="M25 17l-1 12v8l1 12m14-32 1 12v8l-1 12M18 26l6 3h16l6-3M18 40l6-3h16l6 3"/>
      </>}
      {tier.key === 'sapphire' && <>
        <path className="rank-ghost" d="m32 3 22 12 4 22-26 24L6 37l4-22z"/>
        <path className="rank-stroke" d="m32 3 22 12 4 22-26 24L6 37l4-22z"/>
        <path className="rank-thin" d="m32 11 16 9 3 16-19 18-19-18 3-16z"/>
        <path className="rank-stroke" d="m32 17 14 13-5 15H23l-5-15z"/>
        <path className="rank-thin" d="M18 30h28M32 17l-7 13 7 15 7-15-7-13M23 45l2-15m16 15-2-15"/>
      </>}
      {tier.key === 'elite' && <>
        <path className="rank-elite-shield" d="M32 3 54 14v25L32 61 10 39V14z"/>
        <path className="rank-stroke" d="M32 3 54 14v25L32 61 10 39V14z"/>
        <path className="rank-thin rank-elite-inner" d="M32 10 47 19v17L32 52 17 36V19z"/>
        <path className="rank-fill" d="m21 24 7 6 4-11 4 11 7-6-2 15H23z"/>
        <path className="rank-stroke" d="M23 43h18"/>
        <path className="rank-thin" d="m5 23 3 18 12 12m39-30-3 18-12 12"/>
      </>}
      {tier.key === 'legendary' && <>
        <path className="rank-ghost" d="M32 4 48 16 59 15 54 42 32 60 10 42 5 15l11 1z"/>
        <path className="rank-stroke" d="M32 4 48 16 59 15 54 42 32 60 10 42 5 15l11 1z"/>
        <path className="rank-thin" d="M32 11 45 21l8-1-4 19-17 14-17-14-4-19 8 1z"/>
        <path className="rank-fill" d="M33 16c2 8-2 10-2 15 4-2 6-5 7-9 8 8 10 18 5 25-3 5-9 8-11 8s-8-3-11-8c-5-8-2-17 4-23 0 6 2 9 4 11 0-7-1-12 4-19z"/>
      </>}
      {tier.key === 'master' && <>
        <path className="rank-ghost" d="M32 2 43 13l15 2-5 17 5 18-26 12L6 50l5-18-5-17 15-2z"/>
        <path className="rank-stroke rank-master-border" d="M32 2 43 13l15 2-5 17 5 18-26 12L6 50l5-18-5-17 15-2z"/>
        <path className="rank-thin" d="M32 10 41 19l9 1-3 13 3 13-18 8-18-8 3-13-3-13 9-1z"/>
        <path className="rank-fill" d="m32 15 4.5 10 11 1.3-8 7.5 2 11L32 39l-10 5.8 2-11-8-7.5L27.5 25z"/>
        <path className="rank-stroke" d="M22 52 32 57l10-5"/>
      </>}
    </svg>
  </span>;
}
