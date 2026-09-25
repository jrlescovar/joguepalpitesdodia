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
        <path className="rank-fill" d="m21 24 7 6 4-11 4 11 7-6-2 15H23z"/>
        <path className="rank-stroke" d="M23 43h18"/>
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
      {tier.key === 'master' && <>
        <path className="rank-ghost" d="M32 4 48 16 59 15 54 42 32 60 10 42 5 15l11 1z"/>
        <path className="rank-stroke" d="M32 4 48 16 59 15 54 42 32 60 10 42 5 15l11 1z"/>
        <path className="rank-thin" d="M32 11 45 21l8-1-4 19-17 14-17-14-4-19 8 1z"/>
        <path className="rank-fill" d="m32 17 4.3 10.2L47 28l-8.2 7 2.7 10.5L32 40l-9.5 5.5L25.2 35 17 28l10.7-.8z"/>
      </>}
    </svg>
  </span>;
}
