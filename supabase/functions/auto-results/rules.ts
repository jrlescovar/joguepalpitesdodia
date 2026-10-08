export type Target = {
  key: string; kind: 'daily' | 'tournament'; day: string; slot: number; tournamentId: string | null;
  home: string; away: string; competition: string; closesAt: string;
  options: { id: string; label: string }[];
};
export type Fixture = {
  fixture: { id: number; date: string; status: { short: string; elapsed: number | null } };
  league: { name: string; country: string };
  teams: { home: { id: number; name: string }; away: { id: number; name: string } };
  score: { fulltime: { home: number | null; away: number | null } };
};
export type Stats = { team: { id: number }; statistics: { type: string; value: number | string | null }[] };
export type Evidence = { fixtureId: number; kickoff: string; homeId: number; awayId: number; winner: string; homeValue: number; awayValue: number; signature: string };
export const normalize = (value: string) => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]/g, '');
const aliases: Record<string, string> = {
  noruega: 'norway', holanda: 'netherlands', servia: 'serbia', grecia: 'greece', alemanha: 'germany',
  paisdegales: 'wales', dinamarca: 'denmark', irlanda: 'ireland', austria: 'austria', azerbaijao: 'azerbaijan', lituania: 'lithuania',
  franca: 'france', belgica: 'belgium', italia: 'italy', turquia: 'turkey', ucrania: 'ukraine', hungria: 'hungary',
  bosniaeherzegovina: 'bosniaherzegovina', bosnia: 'bosniaherzegovina', polonia: 'poland', romenia: 'romania', suecia: 'sweden',
  inglaterra: 'england', tchequia: 'czechrepublic', czechia: 'czechrepublic', croacia: 'croatia', espanha: 'spain',
  suica: 'switzerland', macedoniadonorte: 'northmacedonia', escocia: 'scotland', eslovenia: 'slovenia', estonia: 'estonia', islandia: 'iceland',
};
const team = (name: string) => aliases[normalize(name)] ?? normalize(name);
function competitionMatches(target: string, league: Fixture['league']) {
  const name = normalize(target), actual = normalize(league.name);
  if (['nationsleague', 'ligadasnacoes', 'uefanationsleague'].includes(name)) return ['nationsleague', 'uefanationsleague'].includes(actual);
  if (['brasileirao', 'brasileiraoseriea'].includes(name)) return normalize(league.country) === 'brazil' && actual === 'seriea';
  return name.length > 0 && name === actual;
}
export function matchFixture(target: Target, fixtures: Fixture[]): Fixture | null {
  const matches = fixtures.filter(f => Number.isSafeInteger(f.fixture?.id) && f.fixture.id > 0
    && team(f.teams?.home?.name ?? '') === team(target.home) && team(f.teams?.away?.name ?? '') === team(target.away)
    && competitionMatches(target.competition, f.league)
    && Math.abs(Date.parse(f.fixture.date) - Date.parse(target.closesAt)) <= 5 * 60_000);
  return matches.length === 1 ? matches[0] : null;
}
function count(value: unknown): number | null {
  // A missing stat must never become zero through Number(null) or Number('').
  if (typeof value !== 'number' && !(typeof value === 'string' && /^\d+$/.test(value))) return null;
  const number = Number(value);
  return Number.isSafeInteger(number) && number >= 0 && number <= 300 ? number : null;
}
export function evaluate(target: Target, fixture: Fixture, stats: Stats[] = []): Evidence | null {
  if (fixture.fixture.status.short !== 'FT' || (fixture.fixture.status.elapsed ?? 0) < 90) return null;
  const getShots = (id: number) => {
    const teams = stats.filter(stat => stat.team.id === id);
    if (teams.length !== 1) return null;
    const values = teams[0].statistics.filter(stat => stat.type === 'Total Shots');
    return values.length === 1 ? count(values[0].value) : null;
  };
  const homeValue = target.kind === 'tournament' ? getShots(fixture.teams.home.id) : count(fixture.score.fulltime.home);
  const awayValue = target.kind === 'tournament' ? getShots(fixture.teams.away.id) : count(fixture.score.fulltime.away);
  if (homeValue === null || awayValue === null) return null;
  const side = homeValue > awayValue ? 'home' : homeValue < awayValue ? 'away' : 'draw';
  const winner = target.kind === 'tournament' ? side : (() => {
    if (target.options.length !== 3) return null;
    const home = target.options.filter(o => team(o.label) === team(target.home));
    const away = target.options.filter(o => team(o.label) === team(target.away));
    const draw = target.options.filter(o => ['x', 'empate'].includes(normalize(o.label)));
    if (home.length !== 1 || away.length !== 1 || draw.length !== 1 || new Set([home[0].id, away[0].id, draw[0].id]).size !== 3) return null;
    return { home: home[0].id, away: away[0].id, draw: draw[0].id }[side];
  })();
  if (!winner) return null;
  const values = [fixture.fixture.id, fixture.fixture.date, fixture.teams.home.id, fixture.teams.away.id, target.kind, winner, homeValue, awayValue];
  return { fixtureId: fixture.fixture.id, kickoff: fixture.fixture.date, homeId: fixture.teams.home.id, awayId: fixture.teams.away.id, winner, homeValue, awayValue, signature: JSON.stringify(values) };
}
