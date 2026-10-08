import { Crown, Swords, Trophy } from 'lucide-react';
import { Avatar } from './components';
import UsernameText from './UsernameText';
import type { PublicProfile } from './types';

type Standing = PublicProfile & {position:number;points:number;greens:number;days:Record<string,{points:number;greens:number}>};
type Match = {key:string;dayId:string;status:string;home:PublicProfile|null;away:PublicProfile|null;homeSeed:number|null;awaySeed:number|null;homePoints:number;awayPoints:number;winnerId:string|null};
export type ArenaWeek = {startsOn:string;status:'qualifying'|'knockout'|'finished';winner:PublicProfile|null;reconstructed:boolean;standings:Standing[];seeds:Array<PublicProfile&{seed:number}>;matches:Match[];days:Array<{dayId:string;status:string;winner:(PublicProfile&{points:number;greens:number})|null}>};
const date = (value:string) => `${value.slice(8,10)}/${value.slice(5,7)}`;
export function ArenaWeekHero({startsOn}:{startsOn:string}) {
 return <div className="card arena-week-hero"><span className="eyebrow">SEMANA DE {date(startsOn)}</span><h2>Uma semana. Um campeão.</h2><div className="arena-week-road"><span><strong>SEG — QUI</strong>Classificação</span><span><strong>SEX</strong>Quartas</span><span><strong>SÁB</strong>Semifinais</span><span><strong>DOM</strong>Final</span></div></div>;
}
const stages = [{title:'Quartas de final',day:'Sexta-feira',keys:['Q1','Q2','Q3','Q4']},{title:'Semifinais',day:'Sábado',keys:['S1','S2']},{title:'Final',day:'Domingo',keys:['F']}];
const seedPairs:Record<string,number[]> = {Q1:[1,8],Q2:[4,5],Q3:[2,7],Q4:[3,6]};
const sources:Record<string,string[]> = {S1:['Q1','Q2'],S2:['Q3','Q4'],F:['S1','S2']};
function WeeklyRankingRow({player,ownUid,onOpen}:{player:Standing;ownUid:string;onOpen:(profile:PublicProfile)=>void}) {
 return <li className={[player.position<=8?'arena-in-cut':'',player.uid===ownUid?'is-me':''].join(' ')}><button type="button" onClick={()=>onOpen(player)} aria-label={`Abrir perfil de ${player.username}, posição ${player.position}, ${player.points} pontos`}><span className="global-rank-position">#{player.position}</span><Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl} borderStyle={player.passBorderStyle}/><span className="global-rank-player"><strong className={`pass-name-${player.passNameStyle??'none'}`}><UsernameText name={player.username} font={player.usernameFont}/></strong></span><strong className="global-rank-points">{player.points}</strong></button></li>;
}
export default function WeeklyArena({week,ownUid,onOpen,view,onViewChange}:{week:ArenaWeek;ownUid:string;onOpen:(profile:PublicProfile)=>void;view:'standings'|'bracket';onViewChange:(view:'standings'|'bracket')=>void}) {
 const ownStanding=week.standings.find(player=>player.uid===ownUid);
 return <section className="weekly-arena">
  <ArenaWeekHero startsOn={week.startsOn}/>
  <div className="arena-week-tabs" role="group" aria-label="Visão da Arena semanal"><button type="button" aria-pressed={view==='standings'} onClick={()=>onViewChange('standings')}><Trophy size={17}/>Melhores 8</button><button type="button" aria-pressed={view==='bracket'} onClick={()=>onViewChange('bracket')}><Swords size={17}/>Mata-mata</button></div>
  {view==='standings' ? <section className="card arena-week-standings"><header><div><h2>Corrida pelo top 8</h2></div><span>TOP 100</span></header>
   <div className="global-ranking-card arena-week-ranking"><div className="global-ranking-heading"><span>TOP 10 / JOGADOR</span><span>PONTOS</span></div>
    <ol className="global-ranking-list">{week.standings.slice(0,10).map(player=><WeeklyRankingRow key={player.uid} player={player} ownUid={ownUid} onOpen={onOpen}/>)}</ol>
    {ownStanding&&ownStanding.position>10&&<div className="global-ranking-own"><div className="global-ranking-own-label">SUA POSIÇÃO</div><ol className="global-ranking-list"><WeeklyRankingRow player={ownStanding} ownUid={ownUid} onOpen={onOpen}/></ol></div>}
   </div>
   <p className="arena-cut-legend"><span/>Os 8 primeiros avançam · desempate por greens, nível</p>
  </section> : <section className="arena-bracket-section"><div className="arena-bracket">{stages.map(stage=><section key={stage.title} className="arena-bracket-stage"><header><span>{stage.day}</span><h3>{stage.title}</h3></header><div>{stage.keys.map(key=>{const match=week.matches.find(m=>m.key===key);return <article key={key} className={`card arena-knockout-match${key==='F'?' arena-final-match':''}`}><header><span>{key==='F'?<Trophy size={15}/>:<Swords size={15}/>} {key==='F'?'A GRANDE FINAL':key}</span><small>{match?.status==='finished'?'Encerrado':match?.status==='open'?'Em disputa':'Aguardando'}</small></header>{[0,1].map(side=>{const fixed=side===0?match?.home:match?.away;const seed=seedPairs[key]?.[side];const projected=seed?week.standings.find(p=>p.position===seed):null;const player=fixed??projected;const winner=!!player&&player.uid===match?.winnerId;return <div className={`arena-knockout-player${winner?' is-winner':''}`} key={side}>{player?<button type="button" onClick={()=>onOpen(player)}><span className="arena-bracket-seed">#{fixed?(side===0?match?.homeSeed:match?.awaySeed):seed}</span><Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl} borderStyle={player.passBorderStyle}/><strong className={`pass-name-${player.passNameStyle ?? 'none'}`}><UsernameText name={player.username} font={player.usernameFont} fitToWidth/></strong>{winner&&<Crown size={16}/>}</button>:<span className="arena-bracket-placeholder">{seed?`${seed}º da classificação`:`Vencedor ${sources[key][side]}`}</span>}<strong className="arena-match-score">{fixed?side===0?match?.homePoints:match?.awayPoints:'—'}</strong></div>;})}</article>;})}</div></section>)}</div>
   <div className="card arena-week-champion"><Trophy size={30}/><div><span>CAMPEÃO DA ARENA</span>{week.winner?<button type="button" onClick={()=>onOpen(week.winner!)}><UsernameText name={week.winner.username} font={week.winner.usernameFont}/></button>:<strong>A coroa espera seu vencedor</strong>}<p>A vitória de domingo concede a medalha e soma 1 título no perfil.</p></div></div>
  </section>}
 </section>;
}








