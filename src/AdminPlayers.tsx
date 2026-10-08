import {useEffect,useState,type FormEvent} from 'react';
import {ArrowLeft,ChevronLeft,ChevronRight,Search,Settings2,Users} from 'lucide-react';
import {call,errorMessage} from './backend';
import {Avatar,ErrorNotice} from './components';
import UsernameText from './UsernameText';
import AdminProfileEditor from './AdminProfileEditor';
import type {PublicProfile} from './types';
import './adminWorkspace.css';
type PlayerPage={players:PublicProfile[];total:number;pages:number;page:number};
export default function AdminPlayers(){
 const [text,setText]=useState(''),[query,setQuery]=useState(''),[page,setPage]=useState(1),[data,setData]=useState<PlayerPage|null>(null),[loading,setLoading]=useState(true),[error,setError]=useState(''),[reload,setReload]=useState(0),[selected,setSelected]=useState<PublicProfile|null>(null);
 useEffect(()=>{let active=true;setLoading(true);setError('');void call<PlayerPage>('getAdminPlayers',{search:query,page}).then(next=>{if(active){setData(next);setPage(next.page);}}).catch(cause=>{if(active)setError(errorMessage(cause));}).finally(()=>{if(active)setLoading(false);});return()=>{active=false;};},[query,page,reload]);
 function search(event:FormEvent){event.preventDefault();setPage(1);setQuery(text.trim());setReload(value=>value+1);}
 if(selected)return <div className="admin-player-workspace"><button className="secondary-button" onClick={()=>{setSelected(null);setReload(value=>value+1);}}><ArrowLeft size={17}/>Voltar aos jogadores</button><AdminProfileEditor key={selected.uid} initialSearch={`#${selected.playerId}`}/></div>;
 return <section className="card admin-directory"><div className="admin-directory-heading"><div><h2><Users size={20}/>Jogadores</h2><p>Escolha um jogador para administrar seu perfil.</p></div><span>{data?.total??'—'} jogadores</span></div>
 <form className="admin-directory-search" onSubmit={search}><label className="sr-only" htmlFor="admin-directory-search">Buscar jogador por nome ou ID</label><input id="admin-directory-search" value={text} onChange={event=>setText(event.target.value)} placeholder="Buscar por nome ou #ID"/><button className="secondary-button" disabled={loading}><Search size={17}/><span>Buscar</span></button></form>
 <div className="admin-directory-pagination"><button className="icon-button" aria-label="Página anterior de jogadores" disabled={loading||page<=1} onClick={()=>setPage(value=>value-1)}><ChevronLeft size={19}/></button><span>Página {data?.page??page} de {data?.pages??1}</span><button className="icon-button" aria-label="Próxima página de jogadores" disabled={loading||page>=(data?.pages??1)} onClick={()=>setPage(value=>value+1)}><ChevronRight size={19}/></button></div>
 {error&&<ErrorNotice message={error} retry={()=>setReload(value=>value+1)}/>}
 <div className="admin-directory-list" aria-busy={loading}>{loading?<p role="status">Carregando jogadores…</p>:data?.players.map(player=><button key={player.uid} className="admin-directory-player" onClick={()=>{setSelected(player);window.scrollTo({top:0,behavior:'instant'});}} aria-label={`Administrar ${player.username}, ID ${player.playerId}`}><Avatar name={player.username} color={player.avatarColor} imageUrl={player.avatarUrl} borderStyle={player.passBorderStyle}/><span><strong className={`pass-name-${player.passNameStyle??'none'}`}><UsernameText name={player.username} font={player.usernameFont}/></strong><small>#{player.playerId} · Nível {player.level??1} · {player.rankPoints??0} pts</small></span><Settings2 size={19}/></button>)}{!loading&&!error&&!data?.players.length&&<p>Nenhum jogador encontrado.</p>}</div>
 </section>;
}
