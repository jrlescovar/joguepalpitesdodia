import type { Prediction } from './types';
import { teamNameDisplay } from './teamNameDisplay';

export const dailyGameLabel = (_game: Pick<Prediction, 'slot'>) => 'Palpites do Dia';

export function dailyCompetitionLabel(description: string): string {
  const label=description.split(/[·\r\n]/,1)[0].trim();
  if (/^(?:(?:Italian\s+)?S[eé]rie\s*A(?:\s+(?:TIM|Enilive|Italiana|It[aá]lia))?|Campeonato\s+Italiano(?:\s+(?:S[eé]rie\s+A|de\s+Futebol))?)$/iu.test(label)) return 'Serie A';
  if (/^(?:(?:1\.\s*|German\s+)?Bundesliga|Campeonato\s+Alem[aã]o)$/iu.test(label)) return 'Bundesliga';
  if (/^(?:La\s*Liga(?:\s+(?:EA\s*Sports|Santander))?|Campeonato\s+Espanhol)$/iu.test(label)) return 'La Liga';
  if (/^(?:(?:English\s+)?Premier\s+League(?:\s+Inglesa)?|Campeonato\s+Ingl[eê]s|Liga\s+Inglesa)$/iu.test(label)) return 'Premier League';
  if (/^(?:Brasileir[aã]o(?:\s+(?:Betano|S[eé]rie\s+A))?|Campeonato\s+Brasileiro(?:\s+(?:S[eé]rie\s+A|de\s+Futebol))?)$/iu.test(label)) return 'Brasileirão';
  if (/^(?:UEFA\s+)?(?:Europa\s+League|Liga\s+Europa)$/iu.test(label)) return 'Liga Europa';
  return /^(?:UEFA\s+)?(?:Champions\s+League|Liga\s+dos\s+Campeões)(?:\s+da\s+UEFA)?$/iu.test(label)
    ? 'Liga dos Campeões' : label;
}

export function orderDailyGames(games: Prediction[]): Prediction[] {
  return [...games].sort((a, b) => {
    return a.closesAt.toMillis() - b.closesAt.toMillis()
      || a.dayId.localeCompare(b.dayId) || a.slot - b.slot;
  });
}

// Use the actual team names in the fixture, rather than a list of market titles.
// Option IDs and rewards stay untouched; neutral and numeric choices keep their meaning.
export function dailyOptionLabel(game: Pick<Prediction, 'title'>, option: Pick<Prediction['options'][number], 'label'>): string {
  const fixture = game.title.match(/\(([^()]+?)\s+(?:x|×|vs\.?)\s+([^()]+?)\)/i);
  const normalize = (text: string) => text.trim().replace(/\s+/g, ' ').toLocaleLowerCase('pt-BR');
  const name = normalize(option.label);
  if (fixture && name === normalize(fixture[1])) return 'Casa';
  if (fixture && name === normalize(fixture[2])) return 'Fora';
  return name === 'empate' ? 'X' : teamNameDisplay(option.label);
}
