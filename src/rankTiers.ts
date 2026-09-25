export const rankTiers = [
  { name: 'Bronze', key: 'bronze', min: 0 },
  { name: 'Prata', key: 'silver', min: 100 },
  { name: 'Ouro', key: 'gold', min: 200 },
  { name: 'Platina', key: 'platinum', min: 300 },
  { name: 'Diamante', key: 'diamond', min: 400 },
  { name: 'Mestre', key: 'master', min: 500 },
] as const;

export function rankTier(points: number) {
  return [...rankTiers].reverse().find(tier => points >= tier.min) ?? rankTiers[0];
}
