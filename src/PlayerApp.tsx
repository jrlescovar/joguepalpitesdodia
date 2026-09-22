import { useEffect,useState,useCallback,useRef } from 'react';
import { ArrowLeft, CalendarDays, CalendarRange, Check, CircleHelp, Crosshair, Flame, Home, LogOut, Settings2, ShieldCheck, Target, Trophy, UserRound, UsersRound, X, Zap } from 'lucide-react';
import { call,errorMessage,logout,type AppUser } from './backend';
import { Brand,LoadingScreen } from './App';
import { Avatar,brasiliaDate,ErrorNotice,Modal,XpBar } from './components';
import { visibleDaily } from './domain';
import type { Prediction,Profile,Session } from './types';
import ProfileForm from './ProfileForm';
import DailyCard from './DailyCard';
import Ranking from './Ranking';
import ProfileOverview from './ProfileOverview';
import Admin from './Admin';
type Tab='temporada'|'grupos'|'inicio'|'ranking'|'perfil';
const tabs=[{id:'temporada',label:'Temporada',icon:CalendarRange},{id:'grupos',label:'Grupos',icon:UsersRound},{id:'inicio',label:'Início',icon:Home},{id:'ranking',label:'Ranking',icon:Trophy},{id:'perfil',label:'Perfil',icon:UserRound}] as const;
function currentTab():Tab {const hash=location.hash.slice(1);return tabs.some(t=>t.id===hash)?hash as Tab:'inicio';}
export default function PlayerApp({user}:{user:AppUser}) {
  const [profile,setProfile]=useState<Profile|null|undefined>();const [session,setSession]=useState<Session|null>(null);const [error,setError]=useState('');const [tab,setTab]=useState<Tab>('inicio');const [retry,setRetry]=useState(0);const [edit,setEdit]=useState(false);const [help,setHelp]=useState(false);const [admin,setAdmin]=useState(false);const [logoutBusy,setLogoutBusy]=useState(false);const [lastClosedPrediction,setLastClosedPrediction]=useState<string|null>(null);const [streakScan,setStreakScan]=useState(0);const [fromRanking,setFromRanking]=useState(false);const rankingScroll=useRef(0);const [restoreRankingScroll,setRestoreRankingScroll]=useState<number|null>(null);
  const refresh=useCallback(async()=>{
    const [nextSession,nextProfile,lastClosed]=await Promise.all([call<Session>('getSession'),call<Profile|null>('getProfile'),call<string|null>('getLastClosedPrediction')]);
    setSession(nextSession);setProfile(nextProfile);setLastClosedPrediction(lastClosed);
  },[]);
  useEffect(()=>{let active=true;setError('');setProfile(undefined);refresh().catch(e=>{if(active)setError(errorMessage(e));});return()=>{active=false;};},[user.uid,retry,refresh]);
  useEffect(()=>{const handler=()=>{setTab(currentTab());setAdmin(false);};addEventListener('hashchange',handler);return()=>removeEventListener('hashchange',handler);},[]);
  useEffect(()=>{if(location.hash!=='#inicio')history.replaceState(null,'','#inicio');},[]);
  useEffect(()=>{const focus=()=>{if(document.visibilityState==='visible')refresh().catch(e=>setError(errorMessage(e)));};document.addEventListener('visibilitychange',focus);return()=>document.removeEventListener('visibilitychange',focus);},[refresh]);
  useEffect(()=>{
    if(!profile||!session)return;
    let active=true;let timer:number|undefined;
    const offset=session.serverTime-Date.now();
    call<Prediction|null>('getCurrentPrediction')
      .then(current=>{
        if(!active)return;
        if(current){
          const delay=Math.max(1000,current.closesAt.toMillis()-Date.now()-offset+1000);
          timer=window.setTimeout(()=>setStreakScan(n=>n+1),Math.min(delay,2147483647));
        }
      }).catch(e=>{if(active)setError(errorMessage(e));});
    return()=>{active=false;if(timer!==undefined)clearTimeout(timer);};
  },[profile?.uid,session?.dayId,streakScan]);
  async function leave(){setLogoutBusy(true);try{await logout();}catch(e){setError(errorMessage(e));setLogoutBusy(false);}}
  function navigate(id:Tab){location.hash=id;setTab(id);setAdmin(false);setFromRanking(false);window.scrollTo({top:0,behavior:'instant'});}
  function openOwnFromRanking(){rankingScroll.current=window.scrollY;navigate('perfil');setFromRanking(true);}
  function backToRanking(){setRestoreRankingScroll(rankingScroll.current);navigate('ranking');}
  if(profile===undefined||!session) {if(!error)return <LoadingScreen label="Carregando seu perfil…"/>;return <div className="setup-shell"><Brand/><ErrorNotice message={error} retry={()=>setRetry(r=>r+1)}/><button className="secondary-button" onClick={leave} disabled={logoutBusy}>Sair da conta</button></div>;}
  if(!profile) return <div className="setup-shell"><Brand/><div className="onboarding card"><div className="eyebrow blue-text">O PRIMEIRO PASSO É SEU</div><h1>Como vamos<br/>chamar você?</h1><p className="muted">Escolha um nome único para entrar no jogo.<br/>Seu ID será criado junto com seu perfil.</p><ProfileForm onDone={()=>void refresh()}/>{error&&<ErrorNotice message={error}/>}<button className="text-button w-full" onClick={leave} disabled={logoutBusy}>Usar outra conta Google</button></div></div>;
  const daily=visibleDaily(profile.dailyStreakCurrent,profile.lastPlayedPrediction,lastClosedPrediction);
  return <div className="app-shell"><a className="skip-link" href="#conteudo">Ir para o conteúdo</a><header className="app-header"><Brand/><div className="flex items-center gap-2"><button className="icon-button" aria-label="Como funciona" onClick={()=>setHelp(true)}><CircleHelp size={20}/></button><button className="avatar-button" onClick={()=>navigate('perfil')} aria-label="Abrir meu perfil"><Avatar name={profile.username} color={profile.avatarColor} imageUrl={profile.avatarUrl}/></button></div></header><main id="conteudo" className="app-main">{error&&<ErrorNotice message={error} retry={()=>{setError('');refresh();}}/>}
    {tab==='inicio'&&<><div className="page-heading home-heading"><div><div className="eyebrow">VERSÃO BETA</div></div><span className="date-label"><CalendarDays size={15}/>{brasiliaDate(session.dayId)}</span></div><div className="dashboard-layout"><div className="dashboard-primary"><section className="player-summary card"><div className="flex items-center gap-3"><Avatar name={profile.username} color={profile.avatarColor} imageUrl={profile.avatarUrl}/><div className="min-w-0 player-summary-identity"><h2>@{profile.username}</h2><span className="muted text-xs">ID #{profile.playerId}</span></div><span className="level-badge">Nível {profile.level}</span></div><XpBar profile={profile} showRemaining={false}/></section><DailyCard key={session.dayId} uid={user.uid} session={session} onChanged={()=>void refresh()}/></div><aside className="dashboard-side"><div className="section-heading"><h2>Seu desempenho</h2><Target size={17}/></div><div className="score-grid"><Stat icon={Check} label="Greens" value={profile.green} tone="green"/><Stat icon={X} label="Reds" value={profile.red} tone="red"/></div><section className="card streak-card"><div className="section-heading"><h2>Continue no ritmo</h2><Flame size={19} className="orange-text"/></div><div className="streak-row"><span><Flame size={17}/> Greens seguidos</span><strong>{profile.greenStreakCurrent}</strong></div><div className="streak-row"><span><Trophy size={17}/> Melhor sequência</span><strong>{profile.greenStreakMax}</strong></div><div className="streak-row"><span><CalendarDays size={17}/> Apostas consecutivas</span><strong>{daily}</strong></div></section></aside></div></>}
    {tab==='temporada'&&<section className="coming-soon"><div className="empty-icon"><CalendarRange size={42}/></div><span className="eyebrow">EM BREVE</span><h1>Temporada<span>.</span></h1><p>Passe, recompensas e desafios da temporada chegarão aqui.</p></section>}
    {tab==='grupos'&&<section className="coming-soon"><div className="empty-icon"><UsersRound size={42}/></div><span className="eyebrow">EM BREVE</span><h1>Grupos<span>.</span></h1><p>Ligas entre amigos e comunidades chegarão aqui.</p></section>}
    {tab==='ranking'&&<Ranking profile={profile} serverTime={session.serverTime} lastClosedPrediction={lastClosedPrediction} onOpenOwnProfile={openOwnFromRanking} restoreScrollY={restoreRankingScroll} onScrollRestored={()=>setRestoreRankingScroll(null)}/>}
    {tab==='perfil'&&!admin&&<>{fromRanking&&<button className="public-profile-back" onClick={backToRanking}><ArrowLeft size={18}/>Voltar ao ranking</button>}<div className="page-heading"><div><h1>Meu perfil<span>.</span></h1></div><button className="secondary-button" onClick={()=>setEdit(true)}><Settings2 size={17}/>Editar perfil</button></div><ProfileOverview profile={profile} lastClosedPrediction={lastClosedPrediction} showBalance/><div className="profile-logout"><button className="secondary-button" onClick={leave} disabled={logoutBusy}><LogOut size={17}/>{logoutBusy?'Saindo…':'Sair da conta'}</button>{session.admin&&<button className="text-button" onClick={()=>setAdmin(true)}><ShieldCheck size={17}/> Administração</button>}</div></>}
    {tab==='perfil'&&admin&&<Admin session={session} onBack={()=>setAdmin(false)}/>}
    </main><nav className="bottom-nav" aria-label="Navegação principal">{tabs.map(({id,label,icon:Icon})=><a key={id} href={`#${id}`} onClick={e=>{e.preventDefault();navigate(id);}} className={`${tab===id?'active':''} ${id==='inicio'?'home-tab':''}`} aria-current={tab===id?'page':undefined}><span><Icon size={21}/></span>{label}</a>)}</nav><Modal open={edit} onOpenChange={setEdit} title="Seu perfil, seu estilo" description="Troque seu nome quando estiver disponível. Depois, aguarde 90 dias para mudar novamente."><ProfileForm key={profile.username} profile={profile} onDone={()=>{setEdit(false);void refresh();}}/></Modal><Modal open={help} onOpenChange={setHelp} title="Um palpite. Todo dia." description="Um jogo gratuito para colocar seu conhecimento à prova."><div className="help-list"><p><Crosshair/> Escolha uma opção antes do prazo. Seu palpite não pode mudar depois da confirmação.</p><p><Check/> Cada acerto vale 1 green e 25 XP. Um red não dá XP e interrompe a sequência de greens.</p><p><Zap/> Cada nível exige 15 XP a mais. O XP que sobra passa para o próximo nível.</p><p><CalendarDays/> Participe de cada aposta para manter sua sequência. Usamos o horário de Brasília.</p><div className="help-credit">Desenvolvido por Jrlescovar</div></div></Modal></div>;
}
function Stat({icon:Icon,label,value,tone,detail}:{icon:typeof Check;label:string;value:number;tone:string;detail?:string}){return <div className={`card stat-card ${tone}`}><span><Icon size={17}/>{label}</span><strong>{value}</strong>{detail&&<small>{detail}</small>}</div>;}
