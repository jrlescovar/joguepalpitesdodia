import { useEffect, useState } from 'react';
import { Trophy } from 'lucide-react';
import { Avatar, ErrorNotice } from './components';
import { call, errorMessage } from './backend';
import UsernameText from './UsernameText';
import type { PublicProfile } from './types';
type Standing = ArenaFighter & {eliminatedOn?:string|null;position:number;points:number;greens:number;days:Record<string,{points:number;greens:number}>};
type ArenaFighter = PublicProfile & {globalPosition?:number};
type Match = {key:string;dayId:string;status:string;home:ArenaFighter|null;away:ArenaFighter|null;homeSeed:number|null;awaySeed:number|null;homePoints:number;awayPoints:number;winnerId:string|null};
export type ArenaWeek = {startsOn:string;settled?:number;status:'qualifying'|'knockout'|'finished';winner:PublicProfile|null;reconstructed:boolean;standings:Standing[];seeds:Array<PublicProfile&{seed:number}>;matches:Match[];days:Array<{dayId:string;status:string;winner:(PublicProfile&{points:number;greens:number})|null}>};

type WeeklyChampion = {startsOn:string;endsOn:string;points:number;greens:number;winner:PublicProfile};
const date = (value:string) => `${value.slice(8,10)}/${value.slice(5,7)}`;
function WeeklyRankingRow({player,ownUid,onOpen}:{player:Standing;ownUid:string;onOpen:(profile:PublicProfile)=>void}) {
 return <li className={[player.uid===ownUid?'arena-is-me is-me':''].join(' ')}><button type="button" onClick={()=>onOpen(player)} aria-label={`Abrir perfil de ${player.username}, posição ${player.position}, ${player.points} pontos${player.eliminatedOn?", eliminado em "+date(player.eliminatedOn):""}`}><span className={`arena-position global-rank-position${player.position===1?' arena-first':player.position===2?' arena-second':player.position===3?' arena-third':''}`}>#{player.position}</span><Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl} borderStyle={player.passBorderStyle}/><span className="arena-player global-rank-player"><strong className={`pass-name-${player.passNameStyle??'none'}`}><UsernameText name={player.username} font={player.usernameFont}/></strong>{player.eliminatedOn&&<small className="liga-eliminated-label">Eliminado {date(player.eliminatedOn)}</small>}</span><span className="arena-points global-rank-points"><strong>{player.points}</strong><small>{player.greens} greens</small></span></button></li>;
}

export default function WeeklyArena({week,ownUid,onOpen}:{week:ArenaWeek;ownUid:string;onOpen:(profile:PublicProfile)=>void}) {
 const endsOn=new Date(Date.parse(week.startsOn+'T12:00:00Z')+6*86400000).toISOString().slice(0,10);
 const ownStanding=week.standings.find(player=>player.uid===ownUid);
 return <section className="weekly-arena">
  <section className="card arena-table global-ranking-card"><header><span><Trophy size={19}/>Liga da Semana {date(week.startsOn)}–{date(endsOn)}</span><strong>{week.settled??0}/70</strong></header>
   <div className="arena-columns global-ranking-heading"><span>JOGADOR</span><span>PTS DA SEMANA</span></div>
    <ol className="global-ranking-list">{week.standings.slice(0,10).map(player=><WeeklyRankingRow key={player.uid} player={player} ownUid={ownUid} onOpen={onOpen}/>)}</ol>
    {ownStanding&&ownStanding.position>10&&<div className="global-ranking-own"><div className="global-ranking-own-label">SUA POSIÇÃO</div><ol className="global-ranking-list"><WeeklyRankingRow player={ownStanding} ownUid={ownUid} onOpen={onOpen}/></ol></div>}
  </section>
  <p className="arena-qualification" role="status">{!ownStanding?'Você não está participando da Liga da Semana.':ownStanding.eliminatedOn?'Você foi eliminado da Liga da Semana.':'Você está participando da Liga da Semana!'}</p>

 </section>;
}

export function WeeklyLigaHistory({onOpen}:{onOpen:(profile:PublicProfile)=>void}) {
 const [history,setHistory]=useState<WeeklyChampion[]>([]);
 const [error,setError]=useState('');
 const [loading,setLoading]=useState(true);
 const [reload,setReload]=useState(0);
 useEffect(()=>{let active=true;setLoading(true);void call<WeeklyChampion[]>('getLigaWeekHistory').then(rows=>{if(active){setHistory(rows);setError('');}}).catch(cause=>{if(active)setError(errorMessage(cause));}).finally(()=>{if(active)setLoading(false);});return()=>{active=false;};},[reload]);
 return (<section className="arena-history liga-week-history">
   {error&&<ErrorNotice message={error} retry={()=>setReload(value=>value+1)}/>}
   {loading&&<p role="status">Carregando campeões…</p>}
   {!loading&&!error&&history.length===0&&<p>Os vencedores aparecerão após o encerramento da semana.</p>}
   <ol className="arena-history-list">{history.map(entry=><li key={entry.startsOn}><button type="button" className="arena-history-card card" onClick={()=>onOpen(entry.winner)} aria-label={`Abrir perfil de ${entry.winner.username}, vencedor de ${date(entry.startsOn)} a ${date(entry.endsOn)}, ${entry.points} pontos`}><span className="arena-history-date liga-week-period"><span>{date(entry.startsOn)}</span><span>{date(entry.endsOn)}</span></span><Avatar name={entry.winner.username} color={entry.winner.avatarColor} imageUrl={entry.winner.avatarUrl} borderStyle={entry.winner.passBorderStyle}/><span className="arena-history-player"><strong className={`pass-name-${entry.winner.passNameStyle??'none'}`}><UsernameText name={entry.winner.username} font={entry.winner.usernameFont}/></strong></span><span className="arena-history-score"><strong>{entry.points.toLocaleString('pt-BR')} pts</strong><small>{entry.greens} greens</small></span></button></li>)}</ol>
  </section>);
}
