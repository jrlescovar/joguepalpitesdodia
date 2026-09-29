import {useEffect,useState} from 'react';
import {ShieldCheck} from 'lucide-react';
import {call} from './backend';
import {Modal} from './components';
import AdminProfileEditor from './AdminProfileEditor';
import type {Session} from './types';
import './adminWorkspace.css';
export default function ProfileAdminPanel({playerId}:{playerId:number}){
 const [allowed,setAllowed]=useState(false),[open,setOpen]=useState(false);
 useEffect(()=>{let active=true;void call<Session>('getSession').then(session=>{if(active)setAllowed(session.admin);}).catch(()=>{});return()=>{active=false;};},[]);
 if(!allowed)return null;
 return <><button className="secondary-button profile-admin-button" onClick={()=>setOpen(true)}><ShieldCheck size={18}/>Administrar jogador</button><Modal className="admin-dialog" open={open} onOpenChange={setOpen} title={`Administrar #${playerId}`}><div className="admin-mode"><AdminProfileEditor key={playerId} initialSearch={`#${playerId}`}/></div></Modal></>;
}

