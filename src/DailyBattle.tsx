import { useEffect, useRef, useState } from 'react';
import { Swords } from 'lucide-react';
import { call, errorMessage } from './backend';
import { Avatar, ErrorNotice } from './components';
import RankEmblem from './RankEmblem';
import type { PublicProfile } from './types';
import './dailyBattle.css';

type Fighter = Pick<PublicProfile, 'uid' | 'username' | 'avatarColor' | 'avatarUrl' | 'passBorderStyle' | 'passNameStyle'> & {
  rankPoints: number;
  globalPosition: number;
};
type ReelCandidate = Omit<Fighter, 'rankPoints' | 'globalPosition'>;
type Battle = {
  dayId: string; preview: boolean; protected: boolean;
  result?: 'open' | 'left' | 'right' | 'draw' | 'no_contest';
  myResult?: 'open' | 'win' | 'loss' | 'draw' | 'no_contest';
  myRankDelta?: number | null;
  hasOpponent?: boolean; scoreVisible?: boolean; myPoints?: number | null; theirPoints?: number | null;
  me?: Fighter; opponent?: Fighter | null; reelCandidates?: ReelCandidate[];
};

const battleDateFormatter = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: '2-digit', timeZone: 'UTC' });
function formatBattleDate(dayId: string, daysAhead = 0) {
  const date = new Date(`${dayId}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + daysAhead);
  return battleDateFormatter.format(date);
}

function FighterTile({ fighter, side, showRank = true }: { fighter: Fighter | ReelCandidate; side: 'me' | 'opponent'; showRank?: boolean }) {
  const rank = 'rankPoints' in fighter && 'globalPosition' in fighter ? fighter : null;
  return <div className={`battle-fighter battle-fighter-${side}`}>
    <span className={`battle-rank${showRank ? '' : ' is-concealed'}`}>
      {showRank && rank && <>{side === 'opponent' && <span>#{rank.globalPosition}</span>}<RankEmblem points={rank.rankPoints}/>{side === 'me' && <span>#{rank.globalPosition}</span>}</>}
    </span>
    <Avatar name={fighter.username} color={fighter.avatarColor} imageUrl={fighter.avatarUrl} borderStyle={fighter.passBorderStyle}/>
    <strong className={`pass-name-${fighter.passNameStyle ?? 'none'}`}>@{fighter.username}</strong>
  </div>;
}

function BattleContent({ battle }: { battle: Battle }) {
  const key = `daily-battle-reveal-${battle.dayId}-${battle.me?.uid}`;
  const alreadyShown = () => Boolean(localStorage.getItem(key)) || window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const [reveal, setReveal] = useState(alreadyShown);
  const [finished, setFinished] = useState(alreadyShown);
  const opponent = battle.opponent;
  useEffect(() => {
    if (!opponent) return;
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduced || localStorage.getItem(key)) { setReveal(true); setFinished(true); return; }
    const start = window.setTimeout(() => setReveal(true), 80);
    const end = window.setTimeout(() => { setFinished(true); localStorage.setItem(key, '1'); }, 2300);
    return () => { clearTimeout(start); clearTimeout(end); };
  }, [key, opponent?.uid]);

  const candidates = battle.reelCandidates ?? [];
  const entries = [0, 1, 2, 3].map(index => candidates[index % candidates.length] ?? opponent!).concat(opponent ? [opponent] : []);
  const battleDate = formatBattleDate(battle.dayId);
  const showScore = !battle.preview && battle.scoreVisible;
  const outcome = !battle.preview && battle.myResult === 'win' ? 'win' : !battle.preview && battle.myResult === 'loss' ? 'loss' : null;
  const resultLabel = outcome === 'win' ? 'GANHOU' : outcome === 'loss' ? 'PERDEU' : '';
  const delta = battle.myRankDelta;
  const deltaLabel = typeof delta === 'number' ? `${delta > 0 ? '+' : delta < 0 ? '−' : ''}${Math.abs(delta)} pts` : null;
  return <section className={`card daily-battle-card${battle.preview ? ' battle-preview' : ''}`} aria-label="Batalha do Dia">
    <div className="battle-heading"><span><Swords size={19} aria-hidden="true"/> BATALHA DO DIA {battleDate}</span>{outcome && deltaLabel && <strong className={`battle-rank-delta battle-tone-${outcome}`} aria-label={`Variação no Ranking: ${deltaLabel}`}>{deltaLabel}</strong>}</div>
    {opponent && battle.me ? <>
      <div className="battle-versus">
        <FighterTile fighter={battle.me} side="me"/>
        <div className={`battle-center${showScore ? ' has-score' : ''}`} role={showScore ? 'status' : undefined} aria-label={showScore ? `${resultLabel ? `${resultLabel}. ` : ''}Placar: ${battle.myPoints ?? 0} pontos a ${battle.theirPoints ?? 0} pontos${outcome && deltaLabel ? `. Ranking: ${deltaLabel}` : ''}` : undefined}>
          {showScore && outcome && <strong className={`battle-result-label battle-tone-${outcome}`}>{resultLabel}</strong>}
          {showScore && <span className={`battle-points${outcome ? ` battle-tone-${outcome}` : ''}`}>{battle.myPoints ?? 0}</span>}
          <span className="battle-center-mark">{showScore && <small aria-hidden="true">pts</small>}<span className="battle-x" aria-hidden="true">X</span></span>
          {showScore && <span className="battle-points">{battle.theirPoints ?? 0}</span>}
        </div>
        <div className="battle-reel-window">
          <span className="battle-sr" role="status">{finished ? `Adversário: ${opponent.username}` : 'Revelando adversário'}</span>
          <div className={`battle-reel-track${reveal ? ' is-revealed' : ''}`} aria-hidden="true">
            {entries.map((fighter, index) => <FighterTile key={`${fighter.uid}-${index}`} fighter={fighter} side="opponent" showRank={finished && index === entries.length - 1}/>)}
          </div>
        </div>
      </div>
      {battle.result === 'no_contest' && <p className="battle-outcome">Sem adversário nesta rodada</p>}
    </> : <div className="battle-waiting">{battle.protected ? 'Proteção ativa. Faça um palpite para voltar ao sorteio.' : battle.preview ? 'Aguardando adversário para amanhã.' : battle.result === 'open' ? 'Aguardando um adversário. Se houver uma vaga, o próximo jogador poderá entrar.' : `A Batalha do Dia ${battleDate} já começou. Aguarde até amanhã, ${formatBattleDate(battle.dayId, 1)}, para participar da próxima.`}</div>}
  </section>;
}

export default function DailyBattle({ refreshTick, onSettled }: { refreshTick: number; onSettled?: () => void }) {
  const [battle, setBattle] = useState<Battle | null>(null);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const lastOutcome = useRef('');
  const onSettledRef = useRef(onSettled);
  onSettledRef.current = onSettled;
  useEffect(() => {
    let active = true;
    let timer: number | undefined;
    const load = () => call<Battle>('getMyDailyBattle').then(value => {
      if (!active) return;
      setBattle(value); setError('');
      const outcome = `${value.dayId}:${value.result}:${value.myRankDelta}`;
      if (!value.preview && (value.myResult === 'win' || value.myResult === 'loss') && lastOutcome.current !== outcome) {
        lastOutcome.current = outcome;
        onSettledRef.current?.();
      }
      if (!value.hasOpponent || (!value.preview && value.result === 'open')) {
        timer = window.setTimeout(() => { if (document.visibilityState === 'visible') void load(); }, 30000);
      }
    }).catch(cause => {
      if (!active) return;
      setError(errorMessage(cause));
      timer = window.setTimeout(() => { if (document.visibilityState === 'visible') void load(); }, 60000);
    });
    void load();
    return () => { active = false; if (timer !== undefined) clearTimeout(timer); };
  }, [refreshTick, reload]);
  if (error) return <ErrorNotice message={`Batalha do Dia: ${error}`} retry={() => setReload(value => value + 1)}/>;
  if (!battle) return <div className="card daily-battle-card battle-waiting" role="status">Preparando Batalha do Dia…</div>;
  return <BattleContent key={`${battle.dayId}-${battle.opponent?.uid ?? 'waiting'}`} battle={battle}/>;
}
