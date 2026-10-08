import { describe, expect, it } from 'vitest';
import { dailyGameLabel, orderDailyGames } from '../src/dailyGameDisplay';
import type { Prediction } from '../src/types';

const game = (slot: number, closes: number, status: Prediction['status'] = 'open') =>
  ({ slot, dayId: '2026-10-07', status, closesAt: { toMillis: () => closes } } as Prediction);

describe('home prediction display', () => {
  it('keeps the daily card first and sorts upcoming extras by deadline', () => {
    const games = [game(1, 500), game(3, 300), game(0, 900), game(2, 400)];
    expect(orderDailyGames(games, 200).map(g => g.slot)).toEqual([0, 3, 2, 1]);
    expect(games.map(g => g.slot)).toEqual([1, 3, 0, 2]);
  });
  it('places expired and settled extras after upcoming games, keeping daily first', () => {
    expect(orderDailyGames([game(1, 100), game(2, 300), game(0, 100, 'settled'), game(3, 400, 'settled')], 200).map(g => g.slot)).toEqual([0, 2, 1, 3]);
  });
  it('keeps equal deadlines deterministic and preserves game identity', () => {
    const games = [game(3, 300), game(2, 300)];
    expect(orderDailyGames(games, 200)).toEqual([games[1], games[0]]);
  });
  it('removes only the extra numbering from player labels', () => {
    expect(dailyGameLabel({slot: 0})).toBe('Palpites do Dia');
    expect(dailyGameLabel({slot: 1})).toBe('Palpite Extra');
    expect(dailyGameLabel({slot: 9})).toBe('Palpite Extra');
  });
});
