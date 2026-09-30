import {useEffect,useRef,useState} from 'react';
import {call,errorMessage} from './backend';
import {ErrorNotice} from './components';
import type {Battle} from './BattleContent';
import BattlePager from './BattlePager';

export default function DailyBattle({ refreshTick, onSettled, onOpenProfile }: { refreshTick: number; onSettled?: () => void; onOpenProfile?: (uid: string) => void }) {
  const [battle, setBattle] = useState<Battle | null>(null);
  const [previousBattle, setPreviousBattle] = useState<Battle | null>(null);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const lastOutcome = useRef('');
  const onSettledRef = useRef(onSettled);
  onSettledRef.current = onSettled;
  useEffect(() => {
    let active = true;
    let timer: number | undefined;
    const load = () => Promise.all([call<Battle>('getMyDailyBattle'), call<Battle | null>('getMyPreviousDailyBattle')]).then(([value, previous]) => {
      if (!active) return;
      setBattle(value); setPreviousBattle(previous); setError('');
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
  if (error) return <ErrorNotice message={`Confronto do Dia: ${error}`} retry={() => setReload(value => value + 1)}/>;
  if (!battle) return <div className="card daily-battle-card battle-waiting" role="status">Preparando Confronto do Dia…</div>;
  return <BattlePager key={battle.dayId} today={battle} previous={previousBattle} onOpenProfile={onOpenProfile}/>;
}
