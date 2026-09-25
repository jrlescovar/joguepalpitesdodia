import { describe, expect, it } from 'vitest';
import { rankTier } from '../src/rankTiers';

describe('graus do Ranking Global', () => {
  it.each([
    [0, 'Bronze'], [99, 'Bronze'],
    [100, 'Prata'], [199, 'Prata'],
    [200, 'Ouro'], [299, 'Ouro'],
    [300, 'Platina'], [399, 'Platina'],
    [400, 'Diamante'], [499, 'Diamante'],
    [500, 'Mestre'], [2000, 'Mestre'],
  ])('classifica %i pontos como %s', (points, name) => {
    expect(rankTier(points).name).toBe(name);
  });
});
