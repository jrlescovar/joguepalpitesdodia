export const rankTiers = [
  { name: 'Bronze', key: 'bronze', min: 0 },
  { name: 'Prata', key: 'silver', min: 100 },
  { name: 'Ouro', key: 'gold', min: 251 },
  { name: 'Platina', key: 'platinum', min: 401 },
  { name: 'Diamante', key: 'diamond', min: 601 },
  { name: 'Lendário', key: 'legendary', min: 851 },
  { name: 'Mestre', key: 'master', min: 1250 },
] as const;

export function rankTier(points: number) {
  return [...rankTiers].reverse().find(tier => points >= tier.min) ?? rankTiers[0];
}
