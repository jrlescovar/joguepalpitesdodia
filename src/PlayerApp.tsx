import Mailbox,{mailFrameStyle} from './Mailbox';
import './styles.css';
import './design.css';
import './usernameFonts.css';
import UsernameText from './UsernameText';
import { useEffect,useLayoutEffect,useState,useCallback,useRef,useMemo } from 'react';
import { ArrowLeft, CalendarDays, Check, CircleHelp, Crosshair, Goal, Home, LogOut, Settings2, Shield, ShieldCheck, ShoppingBag, Swords, Trophy, Zap } from 'lucide-react';
import { call,errorMessage,invalidateReads,logout,type AppUser } from './backend';
import { refreshQueue } from './refreshQueue';
import { Brand,LoadingScreen } from './App';
import { Avatar,brasiliaDate,ErrorNotice,Modal } from './components';
import type { BoxTheme,PassStatus,Prediction,Profile,PublicProfile,Session } from './types';
import {OwnProfileNavigation,usePublicProfileNavigation} from './usePublicProfileNavigation';
type PlayerBootstrap={session:Session;profile:Profile|null;lastClosedPrediction:string|null};
import ProfileForm from './ProfileForm';
import DailyCard from './DailyCard';
import Ranking from './Ranking';
import GlobalRanking from './GlobalRanking';
import RankEmblem from './RankEmblem';
import ProfileOverview from './ProfileOverview';
import Admin from './Admin';
import SupporterPanel from './SupporterPanel';
import BoxCarousel from './BoxCarousel';
import WheelPanel from './WheelPanel';
import CoinShop from './CoinShop';
import InfinitePayReturn, { readInfinitePayReturn } from './InfinitePayReturn';
import RecentResults from './RecentResults';
import Arena from './Arena';
import './ownerStyleVariants.css';
import PodiumIcon from './PodiumIcon';
import FinishingTournament from './FinishingTournament';
import AppErrorBoundary from './AppErrorBoundary';
type Tab='temporada'|'ranking'|'inicio'|'torneio'|'perfil'|'arena'|'greens';
const tabs=[{id:'temporada',label:'Loja',icon:ShoppingBag},{id:'ranking',label:'Ranking',icon:Shield},{id:'inicio',label:'Início',icon:Home},{id:'torneio',label:'Torneio',icon:Trophy},{id:'arena',label:'Liga',icon:Swords}] as const;
function currentTab():Tab {const hash=location.hash.slice(1);return hash==='perfil'||hash==='greens'||tabs.some(t=>t.id===hash)?hash as Tab:'inicio';}
export default function PlayerApp({user}:{user:AppUser}) {
  const [profile,setProfile]=useState<Profile|null|undefined>();const [session,setSession]=useState<Session|null>(null);const [passActive,setPassActive]=useState(false);const [error,setError]=useState('');const [tab,setTab]=useState<Tab>('inicio');const [retry,setRetry]=useState(0);const [edit,setEdit]=useState(false);const [help,setHelp]=useState(false);const [admin,setAdmin]=useState(false);const [logoutBusy,setLogoutBusy]=useState(false);const [lastClosedPrediction,setLastClosedPrediction]=useState<string|null>(null);const [streakScan,setStreakScan]=useState(0);const [refreshTick,setRefreshTick]=useState(0);const [fromGreens,setFromGreens]=useState(false);const greensScroll=useRef(0);const [restoreGreensScroll,setRestoreGreensScroll]=useState<number|null>(null);const previousTab=useRef(tab);const [navTab,setNavTab]=useState<Tab>('inicio');
  const [wheelBoxTarget,setWheelBoxTarget]=useState<BoxTheme|'drops'|'legendary_drops'|null>(null);
  const [battleProfile,setBattleProfile]=useState<PublicProfile|null>(null);
  const {openPublicProfile,cancelProfileOpen,profileOpenNotice}=usePublicProfileNavigation(setBattleProfile,{uid:user.uid,open:()=>navigate('perfil')});
  const finishWheelNavigation=useCallback(()=>setWheelBoxTarget(null),[]);
  const openWheelReward=useCallback((destination:BoxTheme|'legendary'|'supporter')=>{
    if(destination!=='supporter'){setWheelBoxTarget(destination==='legendary'?'legendary_drops':destination);return;}
    requestAnimationFrame(()=>{
      const panel=document.querySelector<HTMLElement>('.shop-layout > .pass-panel');
      panel?.scrollIntoView({block:'center',behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});
      if(panel){panel.tabIndex=-1;panel.focus({preventScroll:true});}
    });
  },[]);
  useEffect(()=>{if(tab!=='temporada')setWheelBoxTarget(null);},[tab]);
  useEffect(()=>{if(tab!=='perfil')setNavTab(tab);},[tab]);
  const lastRefreshAt=useRef(0);const refreshInFlight=useRef(false);const passRefreshGeneration=useRef(0);
  const refresh=useMemo(()=>refreshQueue(async()=>{
    refreshInFlight.current=true;
    const generation=++passRefreshGeneration.current;
    try {
    const {session:nextSession,profile:nextProfile,lastClosedPrediction:lastClosed}=await call<PlayerBootstrap>('getPlayerBootstrap');
    setSession(nextSession);setProfile(nextProfile);setLastClosedPrediction(lastClosed);
    lastRefreshAt.current=Date.now();
    setError('');
    if(nextProfile) void call<PassStatus|null>('getPassStatus').then(status=>{if(generation===passRefreshGeneration.current)setPassActive(Boolean(status?.active));}).catch(()=>{if(generation===passRefreshGeneration.current)setPassActive(false);});
    else setPassActive(false);
    } finally { refreshInFlight.current=false; }
  }),[]);
  useEffect(()=>{let active=true;setError('');setProfile(undefined);refresh().catch(e=>{if(active)setError(errorMessage(e));});return()=>{active=false;};},[user.uid,retry,refresh]);
  useEffect(()=>{const handler=()=>{cancelProfileOpen();setBattleProfile(null);resetTabScroll.current=true;setFromGreens(false);setTab(currentTab());setAdmin(false);};addEventListener('hashchange',handler);return()=>removeEventListener('hashchange',handler);},[cancelProfileOpen]);
  const [boxCheckoutReturn]=useState(()=>new URLSearchParams(location.search).get('boxes'));
  const [infinitePayReturn]=useState(readInfinitePayReturn);
  useEffect(()=>{
    if(boxCheckoutReturn!==null||infinitePayReturn){
      const url=new URL(location.href);
      url.searchParams.delete('boxes');
      if(infinitePayReturn)for(const key of ['payment','order_nsu','transaction_nsu','slug','capture_method','receipt_url','destination'])url.searchParams.delete(key);
      const destination=infinitePayReturn?.destination==='torneio'?'torneio':'temporada';
      url.hash=destination;
      setTab(destination);
      history.replaceState(history.state,'',url.pathname+url.search+url.hash);
    }else{const initial=currentTab();setTab(initial);history.replaceState(null,'',`${location.pathname}${location.search}#${initial}`);}
  },[boxCheckoutReturn,infinitePayReturn]);
  useEffect(()=>{
    const update=()=>{if(document.visibilityState==='visible'){invalidateReads();void refresh().catch(e=>setError(errorMessage(e)));setRefreshTick(value=>value+1);}};
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
  const resetTabScroll = useRef(false);
  useLayoutEffect(() => {
    if (resetTabScroll.current) {
      resetTabScroll.current = false;
      // Reset after the new page is mounted, before painting the fixed mobile menu.
      window.scrollTo({top:0,behavior:'instant'});
    }
  }, [tab]);
  function navigate(id:Tab){cancelProfileOpen();setBattleProfile(null);if(location.hash!==`#${id}`)history.pushState(null,'',`${location.pathname}${location.search}#${id}`);if(id===tab)window.scrollTo({top:0,behavior:'instant'});else resetTabScroll.current=true;setTab(id);setAdmin(false);setFromGreens(false);}
  function openOwnFromGreens(){greensScroll.current=window.scrollY;navigate('perfil');setFromGreens(true);}
  function backToGreens(){setRestoreGreensScroll(greensScroll.current);navigate('greens');}
  if(profile===undefined||!session) {if(!error)return <LoadingScreen label="Carregando seu perfil…"/>;return <div className="setup-shell"><Brand/><ErrorNotice message={error} retry={()=>setRetry(r=>r+1)}/><button className="secondary-button" onClick={leave} disabled={logoutBusy}>Sair da conta</button></div>;}
  if(!profile) return <div className="setup-shell"><Brand/><div className="onboarding card"><div className="eyebrow blue-text">O PRIMEIRO PASSO É SEU</div><h1>Como vamos<br/>chamar você?</h1><p className="muted">Escolha um nome único para entrar no jogo.<br/>Seu ID será criado junto com seu perfil.</p><ProfileForm onDone={()=>void refresh()}/>{error&&<ErrorNotice message={error}/>}<button className="text-button w-full" onClick={leave} disabled={logoutBusy}>Usar outra conta Google</button></div></div>;
  return <OwnProfileNavigation.Provider value={{uid:user.uid,open:()=>navigate('perfil')}}><div className={`app-shell${tab==='torneio'?' app-shell-tournament':''}`}><a className="skip-link" href="#conteudo">Ir para o conteúdo</a><header className="app-header"><Brand/><nav className="desktop-top-nav" aria-label="Navegação principal desktop">{tabs.map(({id,label,icon:Icon})=><a key={id} href={`#${id}`} onClick={e=>{e.preventDefault();navigate(id);}} className={navTab===id?'active':undefined} aria-current={navTab===id?'page':undefined}><Icon size={19}/>{label}</a>)}</nav><div className="app-header-actions flex items-center gap-2">{tab==='inicio'&&<span className="date-label desktop-header-date"><CalendarDays size={15}/>{brasiliaDate(session.dayId)}</span>}<Mailbox profile={profile} refreshTick={refreshTick} onReceived={kind=>{setRefreshTick(v=>v+1);void refresh().catch(e=>setError(errorMessage(e)));if(mailFrameStyle(kind)){navigate('perfil');setEdit(true);}else{navigate('temporada');if(kind==='premium')openWheelReward('supporter');else setWheelBoxTarget(kind==='legendary_drop'?'legendary_drops':kind as 'classic'|'font'|'halloween');}}}/><button className="icon-button" aria-label="Como funciona" onClick={()=>setHelp(true)}><CircleHelp size={20}/></button><a href="#greens" className="icon-button header-greens-button" aria-label="Abrir Top Global de Greens" title="Top Global de Greens" aria-current={tab==='greens'||(tab==='perfil'&&fromGreens)?'page':undefined} onClick={event=>{event.preventDefault();navigate('greens');}}><PodiumIcon/></a><button className="avatar-button" onClick={()=>navigate('perfil')} aria-label="Abrir meu perfil"><Avatar name={profile.username} color={profile.avatarColor} imageUrl={profile.avatarUrl}/></button></div></header><main id="conteudo" className={`app-main${tab==='inicio'?' app-main-home':tab==='ranking'?' app-main-ranking':tab==='torneio'?' app-main-tournament':tab==='arena'?' app-main-league':tab==='perfil'?' app-main-profile':''}`}><AppErrorBoundary key={`${tab}-${admin}`} >{error&&<ErrorNotice message={error} retry={()=>{setError('');refresh();}}/>}
    {infinitePayReturn&&<InfinitePayReturn payment={infinitePayReturn} onPaid={()=>{invalidateReads();setRefreshTick(value=>value+1);void refresh().catch(e=>setError(errorMessage(e)));}}/>}
    {tab==='inicio'&&<><div className="page-heading home-heading"><span className="date-label"><CalendarDays size={15}/>{brasiliaDate(session.dayId)}</span></div><div className="dashboard-layout home-dashboard-layout"><div className="dashboard-primary"><section className="player-summary card" role="button" tabIndex={0} aria-label="Abrir meu perfil" onClick={()=>navigate('perfil')} onKeyDown={event=>{if(event.target===event.currentTarget&&(event.key==='Enter'||event.key===' ')){event.preventDefault();navigate('perfil');}}}><div className="flex items-center gap-3"><Avatar name={profile.username} color={profile.avatarColor} imageUrl={profile.avatarUrl} borderStyle={profile.passBorderStyle}/><div className="min-w-0 player-summary-identity"><h2 className={`pass-name-${profile.passNameStyle ?? 'none'}`}><UsernameText name={profile.username} font={profile.usernameFont} fitToWidth/></h2></div><span className="player-summary-rank"><RankEmblem points={profile.rankPoints ?? 0}/></span><span className="level-badge">Nível {profile.level}</span></div><button type="button" className="home-edit-profile" onClick={event=>{event.stopPropagation();navigate('perfil');}}>clique aqui para editar perfil</button><button type="button" className="home-edit-profile home-edit-profile-bottom" tabIndex={-1} onClick={event=>{event.stopPropagation();navigate('perfil');}}>clique aqui para editar perfil</button></section><DailyCard key={session.dayId} uid={user.uid} session={session} refreshTick={refreshTick} supporterActive={passActive} onChanged={()=>void refresh()}/></div></div><RecentResults refreshTick={refreshTick}/></>}
    {tab==='temporada'&&<div className="shop-layout"><WheelPanel onOpenReward={openWheelReward} profileId={profile.uid} refreshTick={refreshTick} onChanged={()=>{setRefreshTick(value=>value+1);void refresh();}}/><SupporterPanel profile={profile} refreshTick={refreshTick} onChanged={()=>void refresh()}/><CoinShop profile={profile} refreshTick={refreshTick} onBought={theme=>{setRefreshTick(value=>value+1);setWheelBoxTarget(theme);void refresh();}}/><BoxCarousel key={profile.uid} profile={profile} navigateTo={wheelBoxTarget} onNavigated={finishWheelNavigation} refreshAfterCheckout={boxCheckoutReturn==='paid'} refreshTick={refreshTick} onChanged={()=>{setRefreshTick(value=>value+1);void refresh();}}/></div>}
    {tab==='ranking'&&<GlobalRanking today={session.dayId} refreshTick={refreshTick} ownUid={profile.uid} ownPoints={profile.rankPoints ?? 0} lastClosedPrediction={lastClosedPrediction} onBattleSettled={()=>{void refresh().catch(e=>setError(errorMessage(e)));}}/>}
    {tab==='greens'&&<Ranking profile={profile} today={session.dayId} refreshTick={refreshTick} serverTime={session.serverTime} lastClosedPrediction={lastClosedPrediction} onOpenOwnProfile={openOwnFromGreens} restoreScrollY={restoreGreensScroll} onScrollRestored={()=>setRestoreGreensScroll(null)}/>}
    {tab==='torneio'&&<FinishingTournament ownUid={profile.uid} refreshTick={refreshTick} today={session.dayId} lastClosedPrediction={lastClosedPrediction}/> }
    {tab==='arena'&&<Arena ownUid={profile.uid} today={session.dayId} lastClosedPrediction={lastClosedPrediction} refreshTick={refreshTick}/>}
    {tab==='perfil'&&!admin&&!battleProfile&&<>{fromGreens&&<button className="public-profile-back" onClick={backToGreens}><ArrowLeft size={18}/>Voltar ao Top Global de Greens</button>}<div className="page-heading profile-page-heading"><div><h1>Meu perfil<span>.</span></h1></div><div className="profile-heading-actions"><button className="secondary-button" onClick={()=>setEdit(true)}><Settings2 size={17}/>Editar perfil</button></div></div>{profileOpenNotice}<ProfileOverview profile={profile} lastClosedPrediction={lastClosedPrediction} today={session.dayId} supporterActive={passActive} refreshTick={refreshTick} onOpenProfile={openPublicProfile}/><div className="profile-logout"><button className="secondary-button" onClick={leave} disabled={logoutBusy}><LogOut size={17}/>{logoutBusy?'Saindo…':'Sair da conta'}</button>{session.admin&&<button className="text-button" onClick={()=>{setAdmin(true);window.scrollTo({top:0,behavior:'instant'});}}><ShieldCheck size={17}/> Administração</button>}</div></>}
    {tab==='perfil'&&!admin&&battleProfile&&<div className="public-profile-view"><button type="button" className="public-profile-back" onClick={()=>{cancelProfileOpen();setBattleProfile(null);window.scrollTo({top:0,behavior:'instant'});}}><ArrowLeft size={18}/>Voltar ao meu perfil</button><div className="page-heading"><h1>Perfil público<span>.</span></h1></div>{profileOpenNotice}<ProfileOverview profile={battleProfile} lastClosedPrediction={lastClosedPrediction} today={session.dayId} refreshTick={refreshTick} onOpenProfile={openPublicProfile}/></div>}
    {tab==='perfil'&&admin&&<Admin session={session} onBack={()=>{setAdmin(false);window.scrollTo({top:0,behavior:'instant'});setRefreshTick(value=>value+1);void refresh();}}/>}
    </AppErrorBoundary></main><nav className="bottom-nav" aria-label="Navegação principal">{tabs.map(({id,label,icon:Icon})=><a key={id} href={`#${id}`} onClick={e=>{e.preventDefault();navigate(id);}} className={`${navTab===id?'active':''} ${id==='inicio'?'home-tab':''}`} aria-current={navTab===id?'page':undefined}><span><Icon size={21}/></span>{label}</a>)}</nav><Modal open={edit} onOpenChange={setEdit} title="Seu perfil, seu estilo"><ProfileForm key={profile.username} profile={profile} supporterActive={passActive} onDone={()=>{setEdit(false);setRefreshTick(value=>value+1);void refresh();}} onShop={()=>{setEdit(false);navigate('temporada');}}/></Modal><Modal className="gameplay-help-dialog" open={help} onOpenChange={setHelp} title="Como funcionam os palpites" description="O desafio principal pode vir acompanhado de até nove Palpites Extras."><div className="help-list"><p><Crosshair/> Escolha uma opção antes do prazo, no horário de Brasília. Seu palpite não pode mudar depois da confirmação.</p><p><Check/> Cada palpite confirmado vale 5 XP e cada acerto dá 1 green e mais 25 XP. Um erro registra 1 red e interrompe a sequência de greens.</p><p><Goal/> As Extras também contam para greens, reds, sequência de greens e XP. A sequência diária avança no máximo uma vez por dia, somente pelo palpite principal.</p><p><Zap/> Cada nível exige 15 XP a mais. O XP que sobra passa para o próximo nível. Com o Apoiador ativo, cada ganho de XP vale 1,5×, arredondado para cima: 5 vira 8 e 25 vira 38.</p><p><Shield/> PontosRank (pts) medem a dificuldade do acerto. Cada opção tem uma pontuação definida pelo sistema; se você acertar, recebe os pts daquela opção. Se errar, recebe 0 pts.</p><p><Trophy/> O Ranking Global ordena os jogadores pelos pts e mostra o top 10. Os graus vão de Bronze (0–99) até Mestre (2100+). O Top Global de Greens fica no ícone de pódio do cabeçalho e ordena os jogadores por greens e XP. Palpites antigos sem pontos definidos não dão pts.</p><p><CalendarDays/> Participe do palpite principal para manter a sequência diária. As Extras não alteram essa sequência.</p><section className="help-battle" aria-labelledby="help-battle-title"><h3 id="help-battle-title"><Swords size={18}/> Confronto do Dia</h3><p><Shield/> O sorteio procura adversários com pontuação próxima, ampliando a diferença até 500 pts. Entre jogadores com 2100+ pts, não há limite de diferença. O top 10 tem prioridade para conseguir partida. Quem é Mestre no top 10 enfrenta somente jogadores com 2100+ pts, sem preferência por outro integrante do top 10 nem pela diferença de pontos entre Mestres. O palpite principal e os Extras do dia contam para o confronto.</p><p><Crosshair/> Cada acerto soma ao confronto os PontosRank daquela opção. Quando todos os resultados do dia são confirmados, vence quem somou mais pontos.</p><p><Trophy/> Placar igual termina em empate: ninguém ganha nem perde pontos.</p><p><Zap/> Nos confrontos a partir de 19/10/2026 com pelo menos um Mestre (2100+ pts no início do confronto), o vencedor ganha a diferença do placar e o perdedor perde esse mesmo valor. Exemplo: 130 × 100 vale +30/−30 pts; 20 × 100 vale +80/−80 pts. Quando os dois começam abaixo de Mestre, continuam +25/−25 pts se uma patente inferior vence uma superior e +15/−15 pts nos demais casos. O saldo nunca fica negativo.</p><p><CalendarDays/> O mesmo adversário não se repete em dias seguidos. Após dois dias sem palpitar, você fica fora do sorteio normal. Um novo palpite permite participar novamente; o top 10 mantém a prioridade mesmo sem atividade.</p></section><div className="help-credit">Desenvolvido por Jrlescovar</div></div></Modal></div></OwnProfileNavigation.Provider>;
}

