import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it, vi } from 'vitest';
import { BattleContent, type Battle } from '../src/BattleContent';

describe('Confronto do Dia empatado', () => {
  it('mostra empate e +0 pts sem progresso de palpites no resultado final', () => {
    vi.stubGlobal('localStorage', { getItem: () => '1' });
    vi.stubGlobal('window', { matchMedia: () => ({ matches: true }) });
    const fighter = {
      uid: '00000000-0000-4000-8000-000000000001',
      username: 'Jogador', avatarColor: '#3b82f6', avatarUrl: null,
      rankPoints: 108, globalPosition: 1,
    };
    const battle: Battle = {
      dayId: '2026-09-29', preview: false, protected: false,
      result: 'draw', myResult: 'draw', myRankDelta: 0,
      scoreVisible: true, myPoints: 108, theirPoints: 108,
      settledPredictions: 9, totalPredictions: 9,
      me: fighter, opponent: { ...fighter, uid: '00000000-0000-4000-8000-000000000002', username: 'Rival' },
    };
    const html = renderToStaticMarkup(React.createElement(BattleContent, { battle, instant: true }));
    expect(html).toContain('EMPATE');
    expect(html).toContain('+0 pts');
    expect(html).toContain('battle-rank-delta battle-tone-draw');
    expect(html).toContain('battle-center has-score battle-score-draw');
    expect(html).toContain('class="battle-points battle-tone-draw">108</span>');
    expect(html).not.toContain('battle-prediction-progress');
    vi.unstubAllGlobals();
  });
});
