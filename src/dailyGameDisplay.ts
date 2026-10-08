import type { Prediction } from './types';

export const dailyGameLabel = (game: Pick<Prediction, 'slot'>) =>
  game.slot === 0 ? 'Palpites do Dia' : 'Palpite Extra';

export function orderDailyGames(games: Prediction[], now: number): Prediction[] {
  return [...games].sort((a, b) => {
    if ((a.slot === 0) !== (b.slot === 0)) return a.slot === 0 ? -1 : 1;
    const aUpcoming = a.status === 'open' && a.closesAt.toMillis() > now;
    const bUpcoming = b.status === 'open' && b.closesAt.toMillis() > now;
    if (aUpcoming !== bUpcoming) return aUpcoming ? -1 : 1;
    return a.closesAt.toMillis() - b.closesAt.toMillis()
      || a.dayId.localeCompare(b.dayId) || a.slot - b.slot;
  });
}
