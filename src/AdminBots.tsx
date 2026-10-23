import {useEffect,useRef,useState,type FormEvent} from 'react';
import {Bot,ChevronLeft,ChevronRight,Plus,RefreshCw,Search,Trash2} from 'lucide-react';
import {call,errorMessage} from './backend';
import {Avatar,ErrorNotice,Loading} from './components';
import UsernameText from './UsernameText';
import {runBotPickBatches,type BotPickBatch} from './botPickBatches';
import type {PublicProfile} from './types';
import './adminBots.css';

type BotAccount=PublicProfile&{todayPicks:number;tournamentPicks?:number;tournamentTotal?:number};
type BotState={enabled:boolean;ready:boolean;dayId:string;lastRunAt:string|null;lastCreated:number;predictionCount:number;accounts:BotAccount[]};
type PlayerPage={players:PublicProfile[];total:number;pages:number;page:number};

export default function AdminBots(){
 const [data,setData]=useState<BotState|null>(null),[error,setError]=useState(''),[busy,setBusy]=useState(false),[notice,setNotice]=useState('');
 const [text,setText]=useState(''),[query,setQuery]=useState(''),[results,setResults]=useState<PlayerPage|null>(null),[searching,setSearching]=useState(false),[searchError,setSearchError]=useState('');
 const searchGeneration=useRef(0),loadGeneration=useRef(0),operationBusy=useRef(false);
 useEffect(()=>{void load();return()=>{searchGeneration.current++;loadGeneration.current++;};},[]);
 async function load(){
  const generation=++loadGeneration.current;
  operationBusy.current=true;
  setError('');setBusy(true);
  try{const state=await call<BotState>('getAdminDailyBots');if(generation===loadGeneration.current)setData(state);}
  catch(cause){if(generation===loadGeneration.current)setError(errorMessage(cause));}
  finally{if(generation===loadGeneration.current){operationBusy.current=false;setBusy(false);}}
 }
 async function change(name:string,payload:unknown,message:string){
  if(operationBusy.current)return;
  operationBusy.current=true;
  const generation=++loadGeneration.current;
  setBusy(true);setError('');setNotice('');
  try{
   const state=await call<BotState>(name,payload);
   if(generation===loadGeneration.current){setData(state);setNotice(message);}
  }catch(cause){if(generation===loadGeneration.current)setError(errorMessage(cause));}
  finally{if(generation===loadGeneration.current){operationBusy.current=false;setBusy(false);}}
 }
 async function runBots(){
  if(operationBusy.current)return;
  operationBusy.current=true;
  const generation=++loadGeneration.current;
  const active=()=>generation===loadGeneration.current;
  setBusy(true);setError('');setNotice('');
  let saved=0;
  try{
   await runBotPickBatches(
    first=>call<BotState&BotPickBatch>('runAdminBotPickBatch',{first}),active,
    (state,total)=>{saved=total;setData(state);setNotice(`Salvando palpites… ${total} confirmados.`);},
   );
   if(active())setNotice('Execução concluída. Os bots preencheram os palpites de hoje e os torneios em que estão inscritos.');
  }catch(cause){if(active()){
   setNotice(saved?`${saved} palpites já foram salvos. Clique novamente para concluir os que faltam.`:'');
   setError(errorMessage(cause));
  }}finally{if(active()){operationBusy.current=false;setBusy(false);}}
 }
 async function findPlayers(search:string,page=1){
  const generation=++searchGeneration.current;
  setSearching(true);setSearchError('');setQuery(search);
  try{const value=await call<PlayerPage>('getAdminPlayers',{search,page});if(generation===searchGeneration.current)setResults(value);}
  catch(cause){if(generation===searchGeneration.current)setSearchError(errorMessage(cause));}
  finally{if(generation===searchGeneration.current)setSearching(false);}
 }
 function search(event:FormEvent){event.preventDefault();void findPlayers(text.trim());}
 if(!data)return error?<ErrorNotice message={error} retry={()=>void load()}/>:<Loading label="Carregando bots…"/>;
 const ids=new Set(data.accounts.map(account=>account.uid));
 return <div className="admin-bots">
  <section className="card admin-bots-settings">
   <div className="admin-bots-heading"><h2><Bot size={21}/>BOT</h2><button type="button" className="icon-button" aria-label="Atualizar bots" disabled={busy} onClick={()=>void load()}><RefreshCw size={19}/></button></div>
   <p className="muted text-sm">Escolha as contas que serão bots. Ao clicar em “Bots palpitar agora”, elas escolhem uma opção aleatória nos palpites normais de hoje, no horário de Brasília, e nos torneios em que estiverem inscritas.</p>
   <div className="admin-bots-activation"><div><strong>Palpites por botão</strong><span>{data.accounts.length} {data.accounts.length===1?'conta selecionada':'contas selecionadas'}</span></div>
    <button type="button" className="primary-button" disabled={busy||!data.ready||!data.accounts.length} onClick={()=>void runBots()}>{busy?'Palpitando…':'Bots palpitar agora'}</button>
   </div>
   <p className="admin-bots-note">Os bots só palpitam quando você aperta o botão. Nos torneios, participam apenas as contas já inscritas. Nos palpites normais, o botão não preenche datas anteriores ou futuras. Os palpites dos torneios continuam funcionando como antes. Palpites confirmados são preservados e eventos já finalizados não recebem novos palpites.</p>
   {data.lastRunAt&&<p className="admin-bots-note">Última execução: {new Date(data.lastRunAt).toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo'})} · Brasília</p>}
   {error&&<ErrorNotice message={error}/>} {notice&&<p className="success-message" role="status">{notice}</p>}
  </section>
  <section className="card admin-bots-accounts"><h2>Contas dos bots</h2>
   {data.accounts.length?<ul>{data.accounts.map(account=><li key={account.uid} className="admin-bots-player"><Avatar name={account.username} color={account.avatarColor} imageUrl={account.avatarUrl} borderStyle={account.passBorderStyle}/><div className="admin-bots-player-copy"><strong className={`pass-name-${account.passNameStyle??'none'}`}><UsernameText name={account.username} font={account.usernameFont}/></strong><small>#{account.playerId} · {account.todayPicks}/{data.predictionCount} palpites hoje</small>{Boolean(account.tournamentTotal)&&<small>Torneio: {account.tournamentPicks ?? 0}/{account.tournamentTotal} palpites</small>}</div><button type="button" className="icon-button" aria-label={`Remover bot ${account.username}`} disabled={busy} onClick={()=>void change('removeAdminDailyBot',{uid:account.uid},'Conta removida dos bots.')}><Trash2 size={18}/></button></li>)}</ul>:<p className="muted text-sm">Nenhuma conta adicionada.</p>}
  </section>
  <section className="card admin-bots-picker"><h2>Adicionar conta</h2><form className="admin-directory-search" onSubmit={search}><label className="sr-only" htmlFor="admin-bot-search">Buscar conta para bot por nome ou ID</label><input id="admin-bot-search" value={text} onChange={event=>setText(event.target.value)} placeholder="Buscar por nome ou #ID"/><button className="secondary-button" disabled={searching}><Search size={17}/>Buscar</button></form>
   {results&&results.pages>1&&<div className="admin-directory-pagination"><button type="button" className="icon-button" aria-label="Página anterior de contas para bot" disabled={searching||results.page<=1} onClick={()=>void findPlayers(query,results.page-1)}><ChevronLeft size={19}/></button><span>Página {results.page} de {results.pages}</span><button type="button" className="icon-button" aria-label="Próxima página de contas para bot" disabled={searching||results.page>=results.pages} onClick={()=>void findPlayers(query,results.page+1)}><ChevronRight size={19}/></button></div>}
   {searchError&&<ErrorNotice message={searchError} retry={()=>void findPlayers(query,results?.page??1)}/>}
   {searching?<p className="muted text-sm" role="status">Buscando contas…</p>:results?<ul>{results.players.map(player=><li key={player.uid} className="admin-bots-player"><Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl} borderStyle={player.passBorderStyle}/><div className="admin-bots-player-copy"><strong className={`pass-name-${player.passNameStyle??'none'}`}><UsernameText name={player.username} font={player.usernameFont}/></strong><small>#{player.playerId}</small></div><button type="button" className="secondary-button" aria-label={`Adicionar bot ${player.username}`} disabled={busy||ids.has(player.uid)} onClick={()=>void change('addAdminDailyBot',{uid:player.uid},'Conta adicionada aos bots.')}>{ids.has(player.uid)?'Adicionado':<><Plus size={16}/>Adicionar</>}</button></li>)}{results.players.length===0&&<li className="muted text-sm">Nenhuma conta encontrada.</li>}</ul>:<p className="muted text-sm">Busque por nome ou #ID para escolher as contas.</p>}
  </section>
 </div>;
}

