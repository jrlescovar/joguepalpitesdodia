import { describe, expect, it } from 'vitest';
import { evaluate, matchFixture, type Fixture, type Target } from '../supabase/functions/auto-results/rules';
const target: Target = { key: 'daily:2026-10-04:0', kind: 'daily', day: '2026-10-04', slot: 0, tournamentId: null,
  home: 'Portugal', away: 'Noruega', competition: 'Nations League', closesAt: '2026-10-04T15:45:00-03:00',
  options: [{ id: '1', label: 'Portugal' }, { id: '2', label: 'X' }, { id: '3', label: 'Noruega' }] };
const fixture: Fixture = { fixture: { id: 123, date: '2026-10-04T18:45:00Z', status: { short: 'FT', elapsed: 90 } },
  league: { name: 'UEFA Nations League', country: 'World' }, teams: { home: { id: 27, name: 'Portugal' }, away: { id: 28, name: 'Norway' } },
  score: { fulltime: { home: 2, away: 1 } } };
const shots = (home: unknown, away: unknown) => [{ team: { id: 27 }, statistics: [{ type: 'Total Shots', value: home }] }, { team: { id: 28 }, statistics: [{ type: 'Total Shots', value: away }] }] as Parameters<typeof evaluate>[2];
describe('automatic results: explicit match identity and final data', () => {
  it('matches translated team names with correct competition and kickoff', () => expect(matchFixture(target, [fixture])).toBe(fixture));
  it('rejects ambiguous, reversed, rescheduled or wrong-competition fixtures', () => {
    expect(matchFixture(target, [fixture, structuredClone(fixture)])).toBeNull();
    expect(matchFixture(target, [{ ...fixture, teams: { home: fixture.teams.away, away: fixture.teams.home } }])).toBeNull();
    expect(matchFixture(target, [{ ...fixture, fixture: { ...fixture.fixture, date: '2026-10-04T19:45:00Z' } }])).toBeNull();
    expect(matchFixture(target, [{ ...fixture, league: { name: 'Friendlies', country: 'World' } }])).toBeNull();
  });
  it('maps home, draw and away to stored option IDs instead of positional assumptions', () => {
    for (const [home, away, expected] of [[2, 1, '1'], [0, 0, '2'], [0, 3, '3']] as const) {
      const result = evaluate({ ...target, options: [...target.options].reverse() }, { ...fixture, score: { fulltime: { home, away } } });
      expect(result?.winner).toBe(expected);
    }
  });
  it('does not settle live, cancelled, extra-time or penalty matches', () => {
    for (const short of ['2H', 'HT', 'AET', 'PEN', 'CANC', 'ABD', 'PST', 'AWD', 'WO']) expect(evaluate(target, { ...fixture, fixture: { ...fixture.fixture, status: { short, elapsed: 90 } } })).toBeNull();
    expect(evaluate(target, { ...fixture, fixture: { ...fixture.fixture, status: { short: 'FT', elapsed: null } } })).toBeNull();
  });
  it('never treats missing goals or malformed option labels as zero or a draw', () => {
    expect(evaluate(target, { ...fixture, score: { fulltime: { home: null, away: null } } })).toBeNull();
    expect(evaluate({ ...target, options: [...target.options.slice(0, 2), { id: '3', label: 'Suécia' }] }, fixture)).toBeNull();
  });
  it('tournament uses Total Shots including legitimate zero, never shots on target', () => {
    const tournament = { ...target, kind: 'tournament' as const, tournamentId: 'fixture', options: [] };
    expect(evaluate(tournament, fixture, shots(0, 0))?.winner).toBe('draw');
    expect(evaluate(tournament, fixture, shots(15, 9))?.winner).toBe('home');
    expect(evaluate(tournament, fixture, shots(3, 12))?.winner).toBe('away');
    for (const missing of [null, undefined, '', 'unknown', -1, 2.5]) expect(evaluate(tournament, fixture, shots(missing, 4))).toBeNull();
    const wrong = shots(5, 4)!; wrong[0].statistics[0].type = 'Shots on Goal';
    expect(evaluate(tournament, fixture, wrong)).toBeNull();
  });
  it('rejects duplicate team statistics and changes evidence when totals change', () => {
    const tournament = { ...target, kind: 'tournament' as const, tournamentId: 'fixture' };
    expect(evaluate(tournament, fixture, [...shots(5, 4)!, shots(5, 4)![0]])).toBeNull();
    expect(evaluate(tournament, fixture, shots(5, 4))?.signature).not.toBe(evaluate(tournament, fixture, shots(6, 4))?.signature);
  });
});


describe('classic Champions tournament', () => {
  const classic: Target = { ...target, kind: 'tournament', tournamentId: 'champions', metric: 'classic', options: [], competition: 'UEFA Champions League' };
  it('uses the full-time score even when shot totals favor the other side', () => {
    for (const [home, away, expected] of [[2,1,'home'],[0,0,'draw'],[0,3,'away']] as const) {
      const evidence = evaluate(classic, {...fixture,score:{fulltime:{home,away}}},shots(35,0));
      expect(evidence).toMatchObject({winner:expected,homeValue:home,awayValue:away});
    }
  });
  it('does not require shot statistics and refuses missing goals or live scores', () => {
    expect(evaluate(classic,fixture)?.winner).toBe('home');
    expect(evaluate(classic,{...fixture,score:{fulltime:{home:null,away:0}}},shots(9,2))).toBeNull();
    expect(evaluate(classic,{...fixture,fixture:{...fixture.fixture,status:{short:'2H',elapsed:90}}})).toBeNull();
  });
  it('matches Champions identity and kickoff, but rejects other competitions and duplicate fixtures', () => {
    const game={...fixture,league:{name:'UEFA Champions League',country:'World'}};
    expect(matchFixture(classic,[game])).toBe(game);
    expect(matchFixture({...classic,competition:'Champions League'},[game])).toBe(game);
    expect(matchFixture(classic,[fixture])).toBeNull();
    expect(matchFixture(classic,[game,structuredClone(game)])).toBeNull();
  });
});
