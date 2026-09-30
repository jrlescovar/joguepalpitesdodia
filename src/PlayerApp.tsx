import UsernameText from './UsernameText';
import { useEffect,useState,useCallback,useRef } from 'react';
import { ArrowLeft, Bell, CalendarDays, Check, CircleHelp, Crosshair, Goal, Home, LogOut, Settings2, Shield, ShieldCheck, ShoppingBag, Swords, Trophy, Zap } from 'lucide-react';
import { call,errorMessage,logout,type AppUser } from './backend';
import { Brand,LoadingScreen } from './App';
import { Avatar,brasiliaDate,ErrorNotice,Modal } from './components';
import type { PassStatus,Prediction,Profile,Session } from './types';
type PlayerBootstrap={session:Session;profile:Profile|null;lastClosedPrediction:string|null};
import ProfileForm from './ProfileForm';
import DailyCard from './DailyCard';
import Ranking from './Ranking';
import GlobalRanking from './GlobalRanking';
import RankEmblem from './RankEmblem';
import ProfileOverview from './ProfileOverview';
import NotificationSettings from './NotificationSettings';
import Admin from './Admin';
import SupporterPanel from './SupporterPanel';
import BoxPanel from './BoxPanel';
import BoxOffers from './BoxOffers';
import RecentResults from './RecentResults';
import Arena from './Arena';
type Tab='temporada'|'ranking'|'inicio'|'torneio'|'perfil'|'arena';
const tabs=[{id:'temporada',label:'Loja',icon:ShoppingBag},{id:'ranking',label:'Ranking',icon:Shield},{id:'inicio',label:'Início',icon:Home},{id:'torneio',label:'Torneio',icon:Trophy},{id:'arena',label:'Arena',icon:Swords}] as const;
function currentTab():Tab {const hash=location.hash.slice(1);return hash==='perfil'||tabs.some(t=>t.id===hash)?hash as Tab:'inicio';}
export default function PlayerApp({user}:{user:AppUser}) {
  const [profile,setProfile]=useState<Profile|null|undefined>();const [session,setSession]=useState<Session|null>(null);const [passActive,setPassActive]=useState(false);const [error,setError]=useState('');const [tab,setTab]=useState<Tab>('inicio');const [retry,setRetry]=useState(0);const [edit,setEdit]=useState(false);const [notificationsOpen,setNotificationsOpen]=useState(false);const [help,setHelp]=useState(false);const [admin,setAdmin]=useState(false);const [logoutBusy,setLogoutBusy]=useState(false);const [lastClosedPrediction,setLastClosedPrediction]=useState<string|null>(null);const [streakScan,setStreakScan]=useState(0);const [refreshTick,setRefreshTick]=useState(0);const [fromTournament,setFromTournament]=useState(false);const tournamentScroll=useRef(0);const [restoreTournamentScroll,setRestoreTournamentScroll]=useState<number|null>(null);const previousTab=useRef(tab);const [navTab,setNavTab]=useState<Tab>('inicio');
  useEffect(()=>{if(tab!=='perfil')setNavTab(tab);},[tab]);
  const lastRefreshAt=useRef(0);const refreshInFlight=useRef(false);
  const refresh=useCallback(async()=>{
    refreshInFlight.current=true;
    try {
    const {session:nextSession,profile:nextProfile,lastClosedPrediction:lastClosed}=await call<PlayerBootstrap>('getPlayerBootstrap');
    setSession(nextSession);setProfile(nextProfile);setLastClosedPrediction(lastClosed);
    lastRefreshAt.current=Date.now();
    setError('');
    if(nextProfile) void call<PassStatus|null>('getPassStatus').then(status=>setPassActive(Boolean(status?.active))).catch(()=>setPassActive(false));
    else setPassActive(false);
    } finally { refreshInFlight.current=false; }
  },[]);
  useEffect(()=>{let active=true;setError('');setProfile(undefined);refresh().catch(e=>{if(active)setError(errorMessage(e));});return()=>{active=false;};},[user.uid,retry,refresh]);
  useEffect(()=>{const handler=()=>{setTab(currentTab());setAdmin(false);};addEventListener('hashchange',handler);return()=>removeEventListener('hashchange',handler);},[]);
  const [boxCheckoutReturn]=useState(()=>new URLSearchParams(location.search).get('boxes'));
  useEffect(()=>{
    if(boxCheckoutReturn!==null){
      const url=new URL(location.href);
      url.searchParams.delete('boxes');
      url.hash='temporada';
      setTab('temporada');
      history.replaceState(history.state,'',url.pathname+url.search+url.hash);
    }else if(location.hash!=='#inicio')history.replaceState(null,'','#inicio');
  },[boxCheckoutReturn]);
  useEffect(()=>{
    const update=()=>{if(document.visibilityState==='visible'){void refresh().catch(e=>setError(errorMessage(e)));setRefreshTick(value=>value+1);}};
    document.addEventListener('visibilitychange',update);
    const timer=window.setInterval(update,300000);
    return()=>{document.removeEventListener('visibilitychange',update);clearInterval(timer);};
  },[refresh]);
  useEffect(()=>{
    if(previousTab.current===tab)return;
    previousTab.current=tab;
    if(!refreshInFlight.current && Date.now()-lastRefreshAt.current>=120000)
      void refresh().catch(e=>setError(errorMessage(e)));
  },[tab,refresh]);
  useEffect(()=>{
    let idleTimer:number|undefined;
    const onScroll=()=>{
      document.documentElement.classList.add('is-scrolling');
      if(idleTimer!==undefined)clearTimeout(idleTimer);
      idleTimer=window.setTimeout(()=>document.documentElement.classList.remove('is-scrolling'),180);
    };
    document.addEventListener('scroll',onScroll,{capture:true,passive:true});
    return()=>{
      document.removeEventListener('scroll',onScroll,true);
      if(idleTimer!==undefined)clearTimeout(idleTimer);
      document.documentElement.classList.remove('is-scrolling');
    };
  },[]);
  useEffect(()=>{
    if(!profile||!session)return;
    let active=true;let timer:number|undefined;
    const offset=session.serverTime-Date.now();
    call<Prediction[]>('getCurrentPredictions')
      .then(games=>{
        const current=games.filter(game=>game.closesAt.toMillis()>Date.now()+offset).sort((a,b)=>a.closesAt.toMillis()-b.closesAt.toMillis())[0];
        if(!active)return;
        if(current){
          const delay=Math.max(1000,current.closesAt.toMillis()-Date.now()-offset+1000);
          timer=window.setTimeout(()=>{setStreakScan(n=>n+1);void refresh();},Math.min(delay,2147483647));
        }
      }).catch(e=>{if(active)setError(errorMessage(e));});
    return()=>{active=false;if(timer!==undefined)clearTimeout(timer);};
  },[profile?.uid,session?.dayId,streakScan]);
  async function leave(){setLogoutBusy(true);try{await logout();}catch(e){setError(errorMessage(e));setLogoutBusy(false);}}
  function navigate(id:Tab){history.replaceState(null,'',`${location.pathname}${location.search}#${id}`);setTab(id);setAdmin(false);setFromTournament(false);window.scrollTo({top:0,behavior:'instant'});}
  function openOwnFromTournament(){tournamentScroll.current=window.scrollY;navigate('perfil');setFromTournament(true);}
  function backToTournament(){setRestoreTournamentScroll(tournamentScroll.current);navigate('torneio');}
  if(profile===undefined||!session) {if(!error)return <LoadingScreen label="Carregando seu perfil…"/>;return <div className="setup-shell"><Brand/><ErrorNotice message={error} retry={()=>setRetry(r=>r+1)}/><button className="secondary-button" onClick={leave} disabled={logoutBusy}>Sair da conta</button></div>;}
  if(!profile) return <div className="setup-shell"><Brand/><div className="onboarding card"><div className="eyebrow blue-text">O PRIMEIRO PASSO É SEU</div><h1>Como vamos<br/>chamar você?</h1><p className="muted">Escolha um nome único para entrar no jogo.<br/>Seu ID será criado junto com seu perfil.</p><ProfileForm onDone={()=>void refresh()}/>{error&&<ErrorNotice message={error}/>}<button className="text-button w-full" onClick={leave} disabled={logoutBusy}>Usar outra conta Google</button></div></div>;
  return <div className="app-shell"><a className="skip-link" href="#conteudo">Ir para o conteúdo</a><header className="app-header"><Brand/><div className="flex items-center gap-2">{tab==='inicio'&&<span className="date-label desktop-header-date"><CalendarDays size={15}/>{brasiliaDate(session.dayId)}</span>}<button className="icon-button" aria-label="Como funciona" onClick={()=>setHelp(true)}><CircleHelp size={20}/></button><button className="avatar-button" onClick={()=>navigate('perfil')} aria-label="Abrir meu perfil"><Avatar name={profile.username} color={profile.avatarColor} imageUrl={profile.avatarUrl}/></button></div></header><main id="conteudo" className="app-main">{error&&<ErrorNotice message={error} retry={()=>{setError('');refresh();}}/>}
    {tab==='inicio'&&<><div className="page-heading home-heading"><span className="date-label"><CalendarDays size={15}/>{brasiliaDate(session.dayId)}</span></div><div className="dashboard-layout home-dashboard-layout"><div className="dashboard-primary"><section className="player-summary card" role="button" tabIndex={0} aria-label="Abrir meu perfil" onClick={()=>navigate('perfil')} onKeyDown={event=>{if(event.target===event.currentTarget&&(event.key==='Enter'||event.key===' ')){event.preventDefault();navigate('perfil');}}}><div className="flex items-center gap-3"><Avatar name={profile.username} color={profile.avatarColor} imageUrl={profile.avatarUrl} borderStyle={profile.passBorderStyle}/><div className="min-w-0 player-summary-identity"><h2 className={`pass-name-${profile.passNameStyle ?? 'none'}`}><UsernameText name={profile.username} font={profile.usernameFont}/></h2><span className="muted text-xs">ID #{profile.playerId}</span></div><span className="player-summary-rank"><RankEmblem points={profile.rankPoints ?? 0}/></span><span className="level-badge">Nível {profile.level}</span></div><button type="button" className="home-edit-profile" onClick={event=>{event.stopPropagation();setEdit(true);}}>clique aqui para editar perfil</button></section><DailyCard key={session.dayId} uid={user.uid} session={session} refreshTick={refreshTick} supporterActive={passActive} onChanged={()=>void refresh()}/></div></div><RecentResults refreshTick={refreshTick}/></>}
    {tab==='temporada'&&<div className="shop-layout"><SupporterPanel profile={profile} refreshTick={refreshTick} onChanged={()=>void refresh()}/><BoxOffers profile={profile}/><BoxPanel profile={profile} refreshAfterCheckout={boxCheckoutReturn==='paid'} refreshTick={refreshTick} onChanged={()=>{setRefreshTick(value=>value+1);void refresh();}}/><BoxOffers theme="halloween" profile={profile}/><BoxPanel theme="halloween" profile={profile} refreshAfterCheckout={boxCheckoutReturn==='paid'} refreshTick={refreshTick} onChanged={()=>{setRefreshTick(value=>value+1);void refresh();}}/></div>}
    {tab==='ranking'&&<GlobalRanking today={session.dayId} refreshTick={refreshTick} ownUid={profile.uid} ownPoints={profile.rankPoints ?? 0} lastClosedPrediction={lastClosedPrediction} onBattleSettled={()=>{void refresh().catch(e=>setError(errorMessage(e)));}}/>}
    {tab==='torneio'&&<Ranking profile={profile} today={session.dayId} refreshTick={refreshTick} serverTime={session.serverTime} lastClosedPrediction={lastClosedPrediction} onOpenOwnProfile={openOwnFromTournament} restoreScrollY={restoreTournamentScroll} onScrollRestored={()=>setRestoreTournamentScroll(null)}/>}
    {tab==='arena'&&<Arena ownUid={profile.uid} today={session.dayId} lastClosedPrediction={lastClosedPrediction} refreshTick={refreshTick}/>}
    {tab==='perfil'&&!admin&&<>{fromTournament&&<button className="public-profile-back" onClick={backToTournament}><ArrowLeft size={18}/>Voltar ao Torneio</button>}<div className="page-heading profile-page-heading"><div><h1>Meu perfil<span>.</span></h1></div><div className="profile-heading-actions"><button type="button" className="icon-button" aria-label="Avisos no celular" onClick={()=>setNotificationsOpen(true)}><Bell size={19}/></button><button className="secondary-button" onClick={()=>setEdit(true)}><Settings2 size={17}/>Editar perfil</button></div></div><ProfileOverview profile={profile} lastClosedPrediction={lastClosedPrediction} today={session.dayId} showRetrospective supporterActive={passActive} refreshTick={refreshTick}/><div className="profile-logout"><button className="secondary-button" onClick={leave} disabled={logoutBusy}><LogOut size={17}/>{logoutBusy?'Saindo…':'Sair da conta'}</button>{session.admin&&<button className="text-button" onClick={()=>setAdmin(true)}><ShieldCheck size={17}/> Administração</button>}</div></>}
    {tab==='perfil'&&admin&&<Admin session={session} onBack={()=>{setAdmin(false);setRefreshTick(value=>value+1);void refresh();}}/>}
    </main><nav className="bottom-nav" aria-label="Navegação principal">{tabs.map(({id,label,icon:Icon})=><a key={id} href={`#${id}`} onClick={e=>{e.preventDefault();navigate(id);}} className={`${navTab===id?'active':''} ${id==='inicio'?'home-tab':''}`} aria-current={navTab===id?'page':undefined}><span><Icon size={21}/></span>{label}</a>)}</nav><Modal open={notificationsOpen} onOpenChange={setNotificationsOpen} title="Avisos no celular" className="notification-dialog"><NotificationSettings inDialog/></Modal><Modal open={edit} onOpenChange={setEdit} title="Seu perfil, seu estilo"><ProfileForm key={profile.username} profile={profile} supporterActive={passActive} onDone={()=>{setEdit(false);setRefreshTick(value=>value+1);void refresh();}} onShop={()=>{setEdit(false);navigate('temporada');}}/></Modal><Modal open={help} onOpenChange={setHelp} title="Como funcionam os palpites" description="O desafio principal pode vir acompanhado de até nove Palpites Extras."><div className="help-list"><p><Crosshair/> Escolha uma opção antes do prazo, no horário de Brasília. Seu palpite não pode mudar depois da confirmação.</p><p><Check/> Cada palpite confirmado vale 5 XP e cada acerto dá 1 green e mais 25 XP. Um erro registra 1 red e interrompe a sequência de greens.</p><p><Goal/> As Extras também contam para greens, reds, sequência de greens e XP. A sequência diária avança no máximo uma vez por dia, somente pelo palpite principal.</p><p><Zap/> Cada nível exige 15 XP a mais. O XP que sobra passa para o próximo nível. Com a assinatura Seja um Apoiador ativa, cada ganho de XP vale 1,5×, arredondado para cima: 5 vira 8 e 25 vira 38.</p><p><Shield/> PontosRank (pts) medem a dificuldade do acerto. Cada opção tem uma pontuação definida pelo sistema; se você acertar, recebe os pts daquela opção. Se errar, recebe 0 pts.</p><p><Trophy/> O Ranking Global ordena os jogadores pelos pts e mostra o top 10. Os graus vão de Bronze (0–99) até Mestre (2100+). O Torneio continua separado, por greens e XP. Palpites antigos sem pontos definidos não dão pts.</p><p><CalendarDays/> Participe do palpite principal para manter a sequência diária. As Extras não alteram essa sequência.</p><section className="help-battle" aria-labelledby="help-battle-title"><h3 id="help-battle-title"><Swords size={18}/> Batalha do Dia</h3><p><Shield/> A cada dia, você pode enfrentar um jogador com pontuação próxima à sua no Ranking Global. O palpite principal e os Extras do dia contam para a batalha.</p><p><Crosshair/> Cada acerto soma à batalha os PontosRank daquela opção. Quando todos os resultados do dia são confirmados, vence quem somou mais pontos.</p><p><Trophy/> Placar igual termina em empate: ninguém ganha nem perde pontos.</p><p><Zap/> A vitória vale +25 pts e a derrota −25 pts quando uma patente inferior vence uma superior. Nos demais confrontos, são +15/−15 pts, sem deixar o saldo negativo.</p><p><CalendarDays/> Após dois dias sem palpitar, você fica fora do sorteio de adversários. Um novo palpite permite participar novamente.</p></section><div className="help-credit">Desenvolvido por Jrlescovar</div></div></Modal></div>;
}

