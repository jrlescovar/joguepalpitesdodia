import { useState } from 'react';
import { call, errorMessage } from './backend';
import { ErrorNotice, Modal } from './components';
import type { Prediction } from './types';

export default function OpenRankPointsEditor({ prediction, onClose, onSaved }: {
  prediction: Prediction;
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const [values, setValues] = useState(() => prediction.options.map((option, index) => String(option.rankPoints ?? [5, 15, 30, 30][index])));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const valid = values.every(value => /^\d+$/.test(value) && Number(value) >= 1 && Number(value) <= 1000);

  async function save() {
    if (!valid || busy) return;
    setBusy(true);
    setError('');
    try {
      await call('setOpenPredictionRankPoints', {
        dayId: prediction.dayId, slot: prediction.slot, rankPoints: values.map(Number),
      });
      await onSaved();
      onClose();
    } catch (cause) {
      setError(errorMessage(cause));
    } finally {
      setBusy(false);
    }
  }

  return <Modal open onOpenChange={open => { if (!open && !busy) onClose(); }} title="PontosRank da aposta" description="Defina a dificuldade de cada opção antes do encerramento. Se a opção vencer, todos que a escolheram receberão os pontos indicados.">
    <p className="confirm-selection">{prediction.title}</p>
    <div className="open-rank-points-fields">{prediction.options.map((option, index) => <label key={option.id}>
      <span>{option.label}</span>
      <input type="number" min={1} max={1000} step={1} inputMode="numeric" value={values[index]} onChange={event => setValues(current => current.map((value, position) => position === index ? event.target.value : value))} aria-label={`PontosRank para ${option.label}`}/>
    </label>)}</div>
    {error && <ErrorNotice message={error}/>}
    <button className="primary-button w-full mt-5" type="button" onClick={() => void save()} disabled={!valid || busy}>{busy ? 'Salvando…' : 'Salvar pontosRank'}</button>
  </Modal>;
}
