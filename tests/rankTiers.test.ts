import { describe, expect, it } from 'vitest';
import { rankTier } from '../src/rankTiers';

describe('graus do Ranking Global', () => {
  it.each([
    [0, 'Bronze'], [99, 'Bronze'],
    [100, 'Prata'], [149, 'Prata'],
    [150, 'Ouro'], [299, 'Ouro'],
    [300, 'Platina'], [499, 'Platina'],
    [500, 'Diamante'], [749, 'Diamante'],
    [750, 'Lendário'], [999, 'Lendário'],
    [1000, 'Mestre'], [2000, 'Mestre'],
  ])('classifica %i pontos como %s', (points, name) => {
    expect(rankTier(points).name).toBe(name);
  });
});
