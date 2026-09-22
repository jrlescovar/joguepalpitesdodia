import { useEffect,useState } from 'react';
import { Check,Clock3,Goal,LockKeyhole,X,Zap } from 'lucide-react';
import { call,errorMessage } from './backend';
import type { Pick,Prediction,Session } from './types';
import { ErrorNotice } from './components';

function Countdown({until,now}:{until:number;now:number}){
  const remaining=Math.max(0,until-now);const days=Math.floor(remaining/86400000);const hours=Math.floor(remaining%86400000/3600000);const minutes=Math.floor(remaining%3600000/60000);const seconds=Math.floor(remaining%60000/1000);
  return <div className="countdown" role="timer" aria-label={`${days} dias, ${hours} horas, ${minutes} minutos e ${seconds} segundos`}><span><strong>{String(days).padStart(2,'0')}</strong><small>Dias</small></span><span><strong>{String(hours).padStart(2,'0')}</strong><small>Horas</small></span><span><strong>{String(minutes).padStart(2,'0')}</strong><small>Min</small></span><span><strong>{String(seconds).padStart(2,'0')}</strong><small>Seg</small></span></div>;
}

function DailySkeleton(){
  return <div className="daily-skeleton" role="status" aria-label="Buscando a aposta">
    <div className="skeleton-line skeleton-title" aria-hidden="true"/>
    <div className="skeleton-line skeleton-description" aria-hidden="true"/>
    <div className="skeleton-countdown" aria-hidden="true"><i/><i/><i/><i/></div>
    <div className="skeleton-options" aria-hidden="true"><i/><i/><i/></div>
  </div>;
}

export default function DailyCard({uid,session,onChanged}:{uid:string;session:Session;onChanged?:()=>void}){
  const [prediction,setPrediction]=useState<Prediction|null|undefined>();const [pick,setPick]=useState<Pick|null|undefined>();const [selected,setSelected]=useState('');const [error,setError]=useState('');const [busy,setBusy]=useState(false);const [reload,setReload]=useState(0);const [now,setNow]=useState(session.serverTime);
  useEffect(()=>{let active=true;setError('');setPrediction(undefined);call<Prediction|null>('getCurrentPrediction').then(value=>{if(active)setPrediction(value);}).catch(e=>{if(active)setError(errorMessage(e));});return()=>{active=false;};},[reload]);
  useEffect(()=>{let active=true;setSelected('');if(prediction===undefined){setPick(undefined);return()=>{active=false;};}if(!prediction){setPick(null);return()=>{active=false;};}setPick(undefined);call<Pick|null>('getPick',{dayId:prediction.dayId}).then(value=>{if(active)setPick(value);}).catch(e=>{if(active)setError(errorMessage(e));});return()=>{active=false;};},[uid,prediction?.dayId,reload]);
  useEffect(()=>{const offset=session.serverTime-Date.now();const update=()=>setNow(Date.now()+offset);update();const timer=setInterval(update,1000);return()=>clearInterval(timer);},[session.serverTime]);
  async function submit(){if(!prediction||!selected||pick||busy)return;setBusy(true);setError('');try{await call('submitPick',{dayId:prediction.dayId,optionId:selected});setReload(n=>n+1);onChanged?.();}catch(e){setError(errorMessage(e));}finally{setBusy(false);}}
  const expired=prediction ? prediction.closesAt.toMillis()<=now || prediction.status!=='open' : false;
  return <section className="card daily-card"><div className="daily-header"><span><Goal size={18}/> APOSTA DO DIA</span>{(!expired&&!pick)&&<span className="xp-pill"><Zap size={14}/> +5 XP</span>}</div>{error&&<ErrorNotice message={error} retry={()=>setReload(n=>n+1)}/>}
    {(prediction===undefined||pick===undefined)&&!error?<DailySkeleton/>:!prediction?<div className="daily-empty"><div className="empty-icon"><Clock3 size={33}/></div><span className="eyebrow">PRÓXIMA APOSTA</span><h2>Aguardando o próximo desafio</h2><p>Assim que o administrador publicar, a aposta aparecerá aqui.</p></div>:<div className="prediction-content"><h2>{prediction.title}</h2><p className="muted text-sm whitespace-pre-line">{prediction.description}</p><span className={`deadline ${expired?'in-play':''}`}><Clock3 size={14}/>{expired?'EM JOGO':'PALPITES ENCERRAM EM'}</span>{!expired&&<><Countdown until={prediction.closesAt.toMillis()} now={now}/><span className="bet-deadline">Até {prediction.closesAt.toDate().toLocaleDateString('pt-BR',{timeZone:'America/Sao_Paulo',day:'2-digit',month:'long'})}, {prediction.closesAt.toDate().toLocaleTimeString('pt-BR',{timeZone:'America/Sao_Paulo',hour:'2-digit',minute:'2-digit'})} · Brasília</span></>}<fieldset disabled={Boolean(pick)||expired||busy}><legend className="field-label">{pick?'Seu palpite está confirmado':'Qual é o seu palpite?'}</legend><div className={`pick-options options-${prediction.options.length}`}>{prediction.options.map(o=><label key={o.id} className={`${(pick?.optionId||selected)===o.id?'selected':''} ${prediction.winningOptionId===o.id?'winner':''}`}><input type="radio" name="pick" value={o.id} checked={(pick?.optionId||selected)===o.id} onChange={()=>setSelected(o.id)}/><span>{o.label.toLocaleLowerCase('pt-BR')==='empate'?'X':o.label}</span>{prediction.winningOptionId===o.id?<Check size={18}/>:<span className="radio-indicator"/>}</label>)}</div></fieldset>{pick?(pick.status!=='pending'||expired?<div className={`pick-result ${pick.status}`} role="status">{pick.status==='green'?<Check/>:pick.status==='red'?<X/>:<LockKeyhole/>}<span>{pick.status==='green'?'Deu green! +25 XP para você.':pick.status==='red'?'Deu red. A próxima aposta é uma nova chance.':'Em jogo. Aguarde o administrador finalizar o resultado.'}</span></div>:null):!expired?<button className="primary-button w-full mt-5" disabled={!selected||busy} onClick={submit}>{busy?'Confirmando…':'Confirmar meu palpite'} <Check size={18}/></button>:<div className="pick-result pending" role="status"><LockKeyhole/><span>Em jogo. O prazo para novos palpites terminou.</span></div>}</div>}
  </section>;
}
