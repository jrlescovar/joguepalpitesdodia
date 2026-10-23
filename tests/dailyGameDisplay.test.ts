import { describe, expect, it } from 'vitest';
import { dailyGameLabel, dailyCompetitionLabel, dailyOptionLabel, orderDailyGames } from '../src/dailyGameDisplay';
import type { Prediction } from '../src/types';

const game = (slot: number, closes: number, status: Prediction['status'] = 'open') =>
  ({ slot, dayId: '2026-10-07', status, closesAt: { toMillis: () => closes } } as Prediction);

describe('home prediction display', () => {
  it('normalizes Italian Serie A without matching Brazilian or lower division competitions',()=>{
    for(const label of ['Serie A','SerieA','Serie A Enilive','Serie A TIM','Serie A Italiana','Serie A Itália','Italian Serie A','Campeonato Italiano'])expect(dailyCompetitionLabel(label+' · Regra')).toBe('Serie A');
    for(const label of ['Serie B','Coppa Italia','Serie A brasileira','Campeonato Brasileiro Série B'])expect(dailyCompetitionLabel(label+' · Regra')).toBe(label);
    expect(dailyCompetitionLabel('Brasileirão Série A · Regra')).toBe('Brasileirão');
    expect(dailyCompetitionLabel('Campeonato Brasileiro Série A · Regra')).toBe('Brasileirão');
  });
  it('normalizes Bundesliga labels without matching other German competitions',()=>{
    for(const label of ['Bundesliga','1. Bundesliga','German Bundesliga','Campeonato Alemão'])expect(dailyCompetitionLabel(label+' · Regra')).toBe('Bundesliga');
    for(const label of ['2. Bundesliga','DFB Pokal','Supercopa da Alemanha'])expect(dailyCompetitionLabel(label+' · Regra')).toBe(label);
  });
  it('normalizes La Liga labels without matching other Spanish competitions',()=>{
    for(const label of ['La Liga','LaLiga','LALIGA EA SPORTS','La Liga Santander','Campeonato Espanhol'])expect(dailyCompetitionLabel(label+' · Regra')).toBe('La Liga');
    for(const label of ['LaLiga 2','Copa do Rei','Supercopa da Espanha'])expect(dailyCompetitionLabel(label+' · Regra')).toBe(label);
  });
  it('normalizes Premier League names without matching other leagues',()=>{
    for(const label of ['Premier League','English Premier League','Premier League Inglesa','Campeonato Inglês','Liga Inglesa'])expect(dailyCompetitionLabel(label+' · Regra')).toBe('Premier League');
    for(const label of ['Scottish Premiership','Liga Portugal','La Liga'])expect(dailyCompetitionLabel(label+' · Regra')).toBe(label);
  });
  it('normalizes Europa labels without changing other competitions',()=>{
    for(const label of ['Europa League','UEFA Europa League','Liga Europa']) expect(dailyCompetitionLabel(label+' · Regra')).toBe('Liga Europa');
  });
  it('normalizes Champions labels without theming other competitions',()=>{
    for(const description of ['Champions League · Regra','UEFA Champions League\nRegra','Liga dos Campeões · Regra',' Liga dos Campeões da UEFA '])expect(dailyCompetitionLabel(description)).toBe('Liga dos Campeões');
    for(const competition of ['Liga Europa','Copa Sul-Americana','AFC Champions League','CONCACAF Champions League'])expect(dailyCompetitionLabel(competition+' · Regra')).toBe(competition);
  });
  it('sorts every card by kickoff, including the former primary card', () => {
    const games = [game(1, 500), game(3, 300), game(0, 900), game(2, 400)];
    expect(orderDailyGames(games).map(g => g.slot)).toEqual([3, 2, 1, 0]);
    expect(games.map(g => g.slot)).toEqual([1, 3, 0, 2]);
  });
  it('keeps all cards chronological regardless of result status', () => {
    const games = [game(1, 500), game(2, 200, 'settling'), game(0, 900, 'settled'), game(3, 100, 'settled'), game(4, 300)];
    expect(orderDailyGames(games).map(g => g.slot)).toEqual([3, 2, 4, 1, 0]);
    games[4].status = 'settled';
    expect(orderDailyGames(games).map(g => g.slot)).toEqual([3, 2, 4, 1, 0]);
  });
  it('keeps equal deadlines deterministic and preserves game identity', () => {
    const games = [game(3, 300), game(2, 300)];
    expect(orderDailyGames(games)).toEqual([games[1], games[0]]);
  });
  it('uses the same daily title for every slot', () => {
    expect(dailyGameLabel({slot: 0})).toBe('Palpites do Dia');
    expect(dailyGameLabel({slot: 1})).toBe('Palpites do Dia');
    expect(dailyGameLabel({slot: 9})).toBe('Palpites do Dia');
  });
});

describe('daily option names', () => {
  it('maps teams by fixture identity regardless of market, position or option ID', () => {
    for (const market of ['Partida Clássica — Quem vence?', 'Duelo de Cartões?', 'Primeiro a 7 Finalizações?', 'Primeiro a 5 Escanteios?']) {
      const prediction = { title: `${market} (Crystal Palace x Nottingham Forest)` };
      const options = [{ id: 'away', label: 'Nottingham Forest', rankPoints: 30 }, { id: 'none', label: 'Nenhum', rankPoints: 360 }, { id: 'home', label: 'Crystal Palace', rankPoints: 30 }];
      const before = JSON.stringify(options);
      expect(options.map(option => dailyOptionLabel(prediction, option))).toEqual(['Fora', 'Nenhum', 'Casa']);
      expect(JSON.stringify(options)).toBe(before);
    }
  });
  it('preserves numeric and yes/no markets while keeping draw as X', () => {
    const prediction = { title: 'Defesas? (Augsburg x Bayern de Munique)' };
    expect(['0-2', '3-5', '6+', 'Sim', 'Não', 'Nenhum', 'Empate', 'X'].map(label => dailyOptionLabel(prediction, { label }))).toEqual(['0-2', '3-5', '6+', 'Sim', 'Não', 'Nenhum', 'X', 'X']);
    expect(dailyOptionLabel(prediction, { label: 'Bayern de Munique' })).toBe('Fora');
  });
  it('accepts display whitespace/case and preserves choices without a known fixture', () => {
    expect(dailyOptionLabel({ title: 'Vencedor? (Crystal Palace × Nottingham Forest)' }, { label: ' crystal  PALACE ' })).toBe('Casa');
    expect(dailyOptionLabel({ title: 'Total de gols?' }, { label: 'Mais de 2' })).toBe('Mais de 2');
  });
});
