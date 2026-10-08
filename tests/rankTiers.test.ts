import { describe, expect, it } from 'vitest';
import { rankTier } from '../src/rankTiers';

describe('graus do Ranking Global', () => {
  it.each([
    [0, 'Bronze'], [99, 'Bronze'],
    [100, 'Prata'], [250, 'Prata'],
    [251, 'Ouro'], [400, 'Ouro'],
    [401, 'Platina'], [600, 'Platina'],
    [601, 'Diamante'], [900, 'Diamante'],
    [901, 'Esmeralda'], [1200, 'Esmeralda'],
    [1201, 'Safira'], [1500, 'Safira'],
    [1501, 'Lendário'], [1800, 'Lendário'],
    [1801, 'Ascendente'], [2099, 'Ascendente'],
    [2100, 'Mestre'], [3000, 'Mestre'],
  ])('classifica %i pontos como %s', (points, name) => {
    expect(rankTier(points).name).toBe(name);
  });
});
