import { useEffect, useRef, useState, type ReactNode } from 'react';
import { ArrowRight, Check, Clock3, Equal, House, LoaderCircle, LockKeyhole, Plane } from 'lucide-react';
import { call, errorMessage } from './backend';
import { ErrorNotice } from './components';
import { tournamentDay, tournamentOptions, tournamentTime, type FinishingTournamentState, type TournamentOption, type TournamentPrediction } from './finishingTournamentTypes';
import { useCardCarousel } from './useCardCarousel';
import CarouselControls from './CarouselControls';
import './boxCarousel.css';

function TournamentPickCarousel({games,renderGame}:{games:TournamentPrediction[];renderGame:(game:TournamentPrediction)=>ReactNode}) {
  const keys=games.map(game=>String(game.slot));
  const {rail,slides,active,shown,snapStarts,goTo,gestureHandlers}=useCardCarousel(keys,{perPage:1});
  const requested=useRef<number|null>(null);
  useEffect(()=>{
    const container=rail.current;
    if(!container)return;
    let timer:number|undefined;
    // Finish the requested navigation if native swipe momentum interrupted it.
    const finish=()=>{
      clearTimeout(timer);const page=requested.current;if(page===null)return;
      const first=slides.current[keys[0]],target=slides.current[keys[page]];
      if(first&&target&&Math.abs(container.scrollLeft-(target.offsetLeft-first.offsetLeft))>2)goTo(page,true);
    };
    const onScroll=()=>{clearTimeout(timer);timer=window.setTimeout(finish,160);};
    container.addEventListener('scrollend',finish);
    container.addEventListener('scroll',onScroll,{passive:true});
    return()=>{clearTimeout(timer);container.removeEventListener('scrollend',finish);container.removeEventListener('scroll',onScroll);};
  },[keys.join('|')]);
  return <div className="tournament-picks-carousel" aria-label="Palpites deste dia; deslize para os lados" aria-roledescription="carrossel">
    <div className="box-carousel-rail tournament-picks-rail" ref={rail} {...gestureHandlers}
      onPointerDown={event=>{requested.current=null;gestureHandlers.onPointerDown(event);}}
      onWheel={()=>{requested.current=null;gestureHandlers.onWheel();}}>
      {games.map(game=>{const key=String(game.slot);return <div key={key} className="tournament-picks-slide" data-page-start={snapStarts.has(key)} inert={!shown.includes(key)} aria-hidden={!shown.includes(key)}
        ref={element=>{if(element)slides.current[key]=element;else delete slides.current[key];}} role="group" aria-roledescription="slide" aria-label={`Palpite ${game.slot}: ${game.homeTeam} x ${game.awayTeam}`}>
        {renderGame(game)}
      </div>;})}
    </div>
    <CarouselControls active={active} labels={games.map(game=>`palpite ${game.slot}`)} onSelect={page=>{requested.current=page;goTo(page);}} previousLabel="Palpite anterior do torneio" nextLabel="Próximo palpite do torneio"/>
  </div>;
}

export default function TournamentPredictions({ data, offset, today, onSaved }: { data: FinishingTournamentState; offset: number; today: string; onSaved: (data: FinishingTournamentState) => void }) {
  const days = [...new Set(data.predictions.map(game => game.dayId))].sort();
  const [day, setDay] = useState(() => days.includes(today) ? today : days[0]);
  const [selected, setSelected] = useState<Record<number, TournamentOption>>({});
  const [busy, setBusy] = useState<number | null>(null);
  const [error, setError] = useState<{ slot: number; message: string } | null>(null);
  const [now, setNow] = useState(() => Date.now() + offset);
  useEffect(() => {
    const update = () => { if (document.visibilityState === 'visible') setNow(Date.now() + offset); };
    update();
    const timers = data.predictions.filter(game => Date.parse(game.closesAt) > Date.now() + offset)
      .map(game => window.setTimeout(update, Math.min(Date.parse(game.closesAt) - Date.now() - offset + 30, 2147483647)));
    document.addEventListener('visibilitychange', update);
    return () => { timers.forEach(clearTimeout); document.removeEventListener('visibilitychange', update); };
  }, [data.predictions, offset]);
  async function submit(slot: number) {
    const optionId = selected[slot];
    if (!optionId || busy !== null) return;
    setBusy(slot); setError(null);
    try {
      const state = await call<FinishingTournamentState>('submitTournamentPick', { tournamentId: data.id, slot, optionId });
      onSaved(state);
    } catch (cause) { setError({ slot, message: errorMessage(cause) }); }
    finally { setBusy(null); }
  }
  const games = data.predictions.filter(game => game.dayId === day);
  const confirmed = games.filter(game => game.myOptionId).length;
  return <div className="tournament-picks-content">
    <div className="tournament-day-tabs" role="group" aria-label="Dia dos palpites do torneio">
      {days.map(value => <button key={value} type="button" aria-pressed={day === value} onClick={() => setDay(value)}>{tournamentDay(value)}</button>)}
    </div>
    <p className="tournament-picks-progress">{confirmed} / {games.length} confirmados neste dia</p>
    <div className="tournament-day-progress" role="progressbar" aria-label="Palpites confirmados neste dia" aria-valuemin={0} aria-valuemax={games.length} aria-valuenow={confirmed}><span style={{width:`${games.length ? confirmed / games.length * 100 : 0}%`}}/></div>
    <TournamentPickCarousel key={day} games={games} renderGame={game => {
        const closed = game.status !== 'open' || Date.parse(game.closesAt) <= now;
        const picked = game.myOptionId;
        const current = picked ?? selected[game.slot];
        const label = tournamentOptions.find(option => option.id === picked)?.label;
        return <article key={game.slot} className="tournament-pick-card" aria-label={`Palpite ${game.slot}: ${game.homeTeam} x ${game.awayTeam}`}>
          <div className="tournament-pick-meta"><span>{game.competition}</span><span><Clock3 size={13} aria-hidden="true"/>{tournamentTime(game.closesAt)} · Brasília</span></div>
          <h3>{game.title}</h3>
          <div className="tournament-duel"><div><span className="tournament-team-mark" aria-hidden="true"><House size={21}/></span><strong>{game.homeTeam}</strong></div><span className="tournament-duel-versus" aria-hidden="true">VS</span><div><span className="tournament-team-mark" aria-hidden="true"><Plane size={21}/></span><strong>{game.awayTeam}</strong></div></div>
          <p className="tournament-choice-label">{picked ? 'Sua escolha' : closed ? 'Seleção encerrada' : 'Quem recebe mais cartões?'}</p>
          <div className="tournament-pick-options" role="group" aria-label={`Escolha para ${game.homeTeam} x ${game.awayTeam}`}>
            {tournamentOptions.map(option => <button type="button" key={option.id} aria-label={option.label} aria-pressed={current === option.id}
              className={current === option.id ? 'selected' : ''} disabled={Boolean(picked) || closed || busy !== null}
              onClick={() => { setSelected(previous => ({ ...previous, [game.slot]: option.id })); setError(null); }}>
              <span className="tournament-option-symbol" aria-hidden="true">{current === option.id ? <Check size={18}/> : option.id === 'home' ? <House size={18}/> : option.id === 'draw' ? <Equal size={18}/> : <Plane size={18}/>}</span><strong>{option.label}</strong><small>{option.id === 'home' ? 'Mandante' : option.id === 'draw' ? 'Totais iguais' : 'Visitante'}</small>
            </button>)}
          </div>
          {picked ? <p className={`tournament-pick-feedback ${game.myResult ?? ''}`} role="status">
            {game.myResult === 'correct' ? <><Check size={15}/>Acertou · +1 ponto no torneio</>
              : game.myResult === 'incorrect' ? 'Não acertou · 0 pontos no torneio'
              : <><Check size={15}/>Palpite confirmado: {label}</>}
          </p> : closed ? <p className="tournament-pick-feedback"><LockKeyhole size={14}/>Prazo encerrado</p>
            : <button type="button" className="primary-button tournament-pick-submit" disabled={!current || busy !== null} onClick={() => void submit(game.slot)}>
              {busy === game.slot ? <><LoaderCircle size={16} className="spin"/>Confirmando…</> : <>Confirmar palpite<ArrowRight size={17} aria-hidden="true"/></>}
            </button>}
          {game.status === 'settled' && <p className="tournament-pick-result">{game.homeShots !== null && game.awayShots !== null ? `Finalizações: ${game.homeShots} × ${game.awayShots} · ` : ''}Resultado: {tournamentOptions.find(option => option.id === game.winningOptionId)?.label}</p>}
          {error?.slot === game.slot && <ErrorNotice message={error.message}/>}
        </article>;
      }}/>
  </div>;
}

