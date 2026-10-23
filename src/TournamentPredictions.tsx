import { teamNameDisplay } from './teamNameDisplay';
import { dailyCompetitionLabel } from './dailyGameDisplay';
import { useCallback, useEffect, useLayoutEffect, useRef, useState, type ReactNode } from 'react';
import { ArrowRight, Check, Clock3, LoaderCircle, LockKeyhole, X } from 'lucide-react';
import { call, errorMessage } from './backend';
import { ErrorNotice } from './components';
import { tournamentDay, tournamentOptionsFor, tournamentTime, type FinishingTournamentState, type TournamentOption, type TournamentPrediction } from './finishingTournamentTypes';
import { useCardCarousel } from './useCardCarousel';
import CarouselControls from './CarouselControls';
import './boxCarousel.css';

const teamLabel = (name: string) => teamNameDisplay(name).replace(/\bBorussia\b/gi, 'B.');

function TournamentPickCarousel({games,renderGame,onActiveChange}:{games:TournamentPrediction[];renderGame:(game:TournamentPrediction)=>ReactNode;onActiveChange:()=>void}) {
  const keys=games.map(game=>String(game.slot));
  const {rail,slides,active,shown,snapStarts,goTo,gestureHandlers}=useCardCarousel(keys,{perPage:1});
  const requested=useRef<number|null>(null);
  useLayoutEffect(onActiveChange,[active,onActiveChange]);
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
    <CarouselControls compactSelect active={active} labels={games.map(game=>`palpite ${game.slot}`)} onSelect={page=>{requested.current=page;goTo(page);}} previousLabel="Palpite anterior do torneio" nextLabel="Próximo palpite do torneio"/>
  </div>;
}

export default function TournamentPredictions({ data, offset, today, onSaved }: { data: FinishingTournamentState; offset: number; today: string; onSaved: (data: FinishingTournamentState) => void }) {
  const days = [...new Set(data.predictions.map(game => game.dayId))].sort();
  const [day, setDay] = useState(() => days.includes(today) ? today : days[0]);
  const [selected, setSelected] = useState<Record<number, TournamentOption>>({});
  const clearSelection = useCallback(() => setSelected(previous => Object.keys(previous).length ? {} : previous), []);
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
      clearSelection();
      onSaved(state);
    } catch (cause) { setError({ slot, message: errorMessage(cause) }); }
    finally { setBusy(null); }
  }
  const games = data.predictions.filter(game => game.dayId === day);
  const confirmed = games.filter(game => game.myOptionId).length;
  return <div className="tournament-picks-content" data-single-day={days.length===1 || undefined}>
    {days.length > 1 && <div className="tournament-day-tabs" role="group" aria-label="Dia dos palpites do torneio">
      {days.map(value => <button key={value} type="button" aria-pressed={day === value} onClick={() => setDay(value)}>{tournamentDay(value)}</button>)}
    </div>}
    <p className="tournament-picks-progress">{confirmed} / {games.length} confirmados neste dia</p>
    <div className="tournament-day-progress" role="progressbar" aria-label="Palpites confirmados neste dia" aria-valuemin={0} aria-valuemax={games.length} aria-valuenow={confirmed}><span style={{width:`${games.length ? confirmed / games.length * 100 : 0}%`}}/></div>
    <TournamentPickCarousel key={day} games={games} onActiveChange={clearSelection} renderGame={game => {
        const options = tournamentOptionsFor(data.metric, game);
        const closed = game.status !== 'open' || Date.parse(game.closesAt) <= now;
        const picked = game.myOptionId;
        const current = picked ?? selected[game.slot];
        return <article key={game.slot} className="tournament-pick-card" aria-label={`Palpite ${game.slot}: ${game.homeTeam} x ${game.awayTeam}`}>
          <div className="tournament-pick-meta"><span>{dailyCompetitionLabel(game.competition)}</span><span><Clock3 size={13} aria-hidden="true"/>{game.status === 'open' && Date.parse(game.closesAt) <= now ? 'Em Jogo' : `${tournamentTime(game.closesAt)} · Brasília`}</span></div>
          <h3>{game.title}</h3>
          <div className="tournament-duel"><div><strong>{teamLabel(game.homeTeam)}</strong></div><span className="tournament-duel-versus" aria-hidden="true">VS</span><div><strong>{teamLabel(game.awayTeam)}</strong></div></div>
          {!picked && (closed || (data.metric !== 'classic' && data.metric !== 'mixed')) && <p className="tournament-choice-label">{closed ? 'Seleção encerrada' : data.metric === 'cards' ? 'Quem recebe mais cartões?' : 'Quem terá mais finalizações?'}</p>}
          <div className={`tournament-pick-options${options.length === 2 ? ' tournament-options-binary' : ''}`} role="group" aria-label={`Escolha para ${game.title}: ${game.homeTeam} x ${game.awayTeam}`}>
            {options.map(option => <button type="button" key={option.id} aria-label={option.label} aria-pressed={current === option.id}
              className={`${current === option.id ? 'selected' : ''}${game.status === 'settled' && game.winningOptionId === option.id ? ' correct' : ''}`} aria-description={game.status === 'settled' && game.winningOptionId === option.id ? 'Opção correta' : undefined} disabled={Boolean(picked) || closed || busy !== null}
              onClick={() => { setSelected(previous => previous[game.slot] === option.id ? {} : { [game.slot]: option.id }); setError(null); }}>
              <strong>{option.label}</strong>
            </button>)}
          </div>
          {picked ? null : closed ? <p className="tournament-pick-feedback"><LockKeyhole size={14}/>Prazo encerrado</p>
            : current && <button type="button" className="primary-button tournament-pick-submit" disabled={busy !== null} onClick={() => void submit(game.slot)}>
              {busy === game.slot ? <><LoaderCircle size={16} className="spin"/>Confirmando…</> : <>Confirmar palpite<ArrowRight size={17} aria-hidden="true"/></>}
            </button>}
          {picked && game.status === 'settled' && <div className={`pick-result tournament-outcome ${picked === game.winningOptionId ? 'green' : 'red'}`} role="status">
            {picked === game.winningOptionId ? <Check aria-hidden="true"/> : <X aria-hidden="true"/>}
            <span>{picked === game.winningOptionId ? 'Deu green! +1 pts para você.' : 'Deu red.'}</span>
          </div>}
          {picked && game.status === 'open' && closed && <div className="pick-result tournament-outcome in-progress" role="status">
            <Clock3 aria-hidden="true"/>
            <span>Em andamento</span>
          </div>}
          {error?.slot === game.slot && <ErrorNotice message={error.message}/>}
        </article>;
      }}/>
  </div>;
}

