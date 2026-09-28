export const rankTiers = [
  { name: 'Bronze', key: 'bronze', min: 0 },
  { name: 'Prata', key: 'silver', min: 100 },
  { name: 'Ouro', key: 'gold', min: 251 },
  { name: 'Platina', key: 'platinum', min: 401 },
  { name: 'Diamante', key: 'diamond', min: 601 },
  { name: 'Esmeralda', key: 'emerald', min: 901 },
  { name: 'Safira', key: 'sapphire', min: 1201 },
  { name: 'Lendário', key: 'legendary', min: 1501 },
  { name: 'Elite', key: 'elite', min: 1801 },
  { name: 'Mestre', key: 'master', min: 2100 },
] as const;

export function rankTier(points: number) {
  return [...rankTiers].reverse().find(tier => points >= tier.min) ?? rankTiers[0];
}
