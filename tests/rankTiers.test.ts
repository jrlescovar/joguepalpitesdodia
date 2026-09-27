import { describe, expect, it } from 'vitest';
import { rankTier } from '../src/rankTiers';

describe('graus do Ranking Global', () => {
  it.each([
    [0, 'Bronze'], [99, 'Bronze'],
    [100, 'Prata'], [250, 'Prata'],
    [251, 'Ouro'], [400, 'Ouro'],
    [401, 'Platina'], [600, 'Platina'],
    [601, 'Diamante'], [850, 'Diamante'],
    [851, 'Lendário'], [1249, 'Lendário'],
    [1250, 'Mestre'], [2000, 'Mestre'],
  ])('classifica %i pontos como %s', (points, name) => {
    expect(rankTier(points).name).toBe(name);
  });
});
