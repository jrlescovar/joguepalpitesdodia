import {useCallback,useEffect,useRef,useState} from 'react';
import {call,errorMessage} from './backend';
import {ErrorNotice} from './components';
import type {PublicProfile} from './types';

export function usePublicProfileNavigation(onOpen:(profile:PublicProfile)=>void) {
  const onOpenRef=useRef(onOpen);
  onOpenRef.current=onOpen;
  const request=useRef(0);
  const target=useRef('');
  const [loading,setLoading]=useState(false);
  const [error,setError]=useState('');
  useEffect(()=>()=>{request.current++;},[]);
  const cancelProfileOpen=useCallback(()=>{request.current++;setLoading(false);setError('');},[]);
  const openPublicProfile=useCallback((uid:string)=>{
    const generation=++request.current;
    target.current=uid;setLoading(true);setError('');
    void call<PublicProfile|null>('getPublicProfile',{uid}).then(profile=>{
      if(generation!==request.current)return;
      if(!profile)throw new Error('Perfil indisponível no momento.');
      onOpenRef.current(profile);
      window.scrollTo({top:0,behavior:'instant'});
    }).catch(cause=>{if(generation===request.current)setError(errorMessage(cause));})
      .finally(()=>{if(generation===request.current)setLoading(false);});
  },[]);
  const profileOpenNotice=error?<ErrorNotice message={error} retry={()=>openPublicProfile(target.current)}/>
    :loading?<p className="muted text-sm" role="status">Carregando perfil…</p>:null;
  return {openPublicProfile,cancelProfileOpen,profileOpenNotice};
}
