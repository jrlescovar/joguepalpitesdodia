import { useEffect,useState,type FormEvent } from 'react';
import { Check, LoaderCircle, LockKeyhole } from 'lucide-react';
import { call,errorMessage } from './backend';
import { avatarColors,colorNames,type Profile, type PassStatus, type PassNameStyle, type PassBorderStyle, type BoxState } from './types';
import { Avatar,ErrorNotice } from './components';
import { commonPassStyles, passStyleOptions } from './passStyleOptions';
const epicStyles=new Set<PassNameStyle>(['midnight-electric','graphite-silver','wine-rose','neon-circuit','sunset-ocean','rare-plum-beige']);
const styleCategory=(style:PassNameStyle)=>style==='gold'||style==='rainbow'||style.startsWith('legend-')?'legend':style.startsWith('myth-')?'myth':epicStyles.has(style)?'epic':commonPassStyles.has(style)?null:'rare';
const categoryName={rare:'Rara',epic:'Épica',myth:'Mítica',legend:'Lendária'};
export default function ProfileForm({profile,onDone}:{profile?:Profile;onDone?:()=>void;onShop?:()=>void;supporterActive?:boolean}) {
  const [username,setUsername]=useState(profile?.username||'');const [color,setColor]=useState(profile&&avatarColors.includes(profile.avatarColor)?profile.avatarColor:avatarColors[0]);
  const [useGoogleAvatar,setUseGoogleAvatar]=useState(profile?.useGoogleAvatar!==false);
  const [pass,setPass]=useState<PassStatus|null>(null);
  const [box,setBox]=useState<BoxState|null>(null);
  const [nameStyle,setNameStyle]=useState<PassNameStyle>(profile?.passNameStyle??'none');
  const [borderStyle,setBorderStyle]=useState<PassBorderStyle>(profile?.passBorderStyle??'none');
  const [styleTab,setStyleTab]=useState<'name'|'frame'|'font'>('name');
  const allStylesUnlocked=profile?.playerId===1000001;
  const canStyle=allStylesUnlocked||Boolean(box?.inventory.length);
  const unlockedNames=new Set(box?.inventory.filter(item=>item.kind==='name').map(item=>item.style));
  const unlockedFrames=new Set(box?.inventory.filter(item=>item.kind==='frame').map(item=>item.style));
  const visibleNameStyles=passStyleOptions.filter(([style])=>style==='none'||allStylesUnlocked||unlockedNames.has(style));
  const visibleFrameStyles=passStyleOptions.filter(([style])=>style==='none'||allStylesUnlocked||unlockedFrames.has(style));
  useEffect(()=>{if(!profile)return;let active=true;call<PassStatus>('getPassStatus').then(status=>{if(active){setPass(status);setNameStyle(current=>current===profile.passNameStyle?status.nameStyle:current);setBorderStyle(current=>current===profile.passBorderStyle?status.borderStyle:current);}}).catch(()=>{});return()=>{active=false;};},[profile?.uid]);
  useEffect(()=>{if(!profile)return;let active=true;call<BoxState>('getBoxState').then(state=>{if(active)setBox(state);}).catch(()=>{});return()=>{active=false;};},[profile?.uid]);
  const [availability,setAvailability]=useState<'idle'|'checking'|'available'|'taken'|'invalid'|'error'>('idle');const [busy,setBusy]=useState(false);const [error,setError]=useState('');
  const nextUsernameChange=profile?.usernameChangedAt?Date.parse(profile.usernameChangedAt)+90*86400000:0;
  const usernameLocked=Boolean(profile&&nextUsernameChange>Date.now());
  const usernameChangeDate=usernameLocked?new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Sao_Paulo'}).format(new Date(nextUsernameChange)):'';
  useEffect(()=>{let active=true;if(!/^[a-zA-Z0-9_]{3,12}$/.test(username)){setAvailability(username?'invalid':'idle');return;}if(profile&&username.toLowerCase()===profile.username.toLowerCase()){setAvailability('available');return;}setAvailability('checking');const timer=setTimeout(()=>{call<{available:boolean;valid:boolean}>('checkUsername',{username}).then(r=>{if(active)setAvailability(!r.valid?'invalid':r.available?'available':'taken');}).catch(e=>{if(active){setAvailability('error');setError(errorMessage(e));}});},400);return()=>{active=false;clearTimeout(timer);};},[username,profile?.username]);
  const usernameChanged = !profile || username.toLowerCase() !== profile.username.toLowerCase();
  async function save(e:FormEvent){e.preventDefault();setBusy(true);setError('');try{await call(profile?'updateProfile':'createAccount',{username,avatarColor:color,useGoogleAvatar});if(profile&&canStyle&&(nameStyle!==(pass?.nameStyle??profile.passNameStyle??'none')||borderStyle!==(pass?.borderStyle??profile.passBorderStyle??'none')))await call('setPassStyles',{borderStyle,nameStyle});onDone?.();}catch(e){setError(errorMessage(e));}finally{setBusy(false);}}
  const hints={idle:'De 3 a 12 letras, números ou underscore.',checking:'Verificando disponibilidade…',available:'Nome disponível. Pode chamar de seu.',taken:'Este nome já está em uso. Tente outro.',invalid:'Use de 3 a 12 letras, números ou underscore. Nomes oficiais são reservados.',error:'Não foi possível verificar agora.'};
  return <form onSubmit={save} className="profile-form"><div className="avatar-choice"><Avatar name={username||'?'} color={color} imageUrl={useGoogleAvatar?profile?.avatarUrl:null} borderStyle={canStyle?borderStyle:'none'} large/><div><strong>Com a sua cara.</strong><p>{!useGoogleAvatar?'Avatar tradicional.':profile?.avatarUrl?'Foto da sua conta Google.':'A foto será atualizada no próximo login.'}</p></div></div>{profile&&<div className="google-photo-setting"><div><strong>Usar foto do Google</strong><span>Desative para usar sua inicial colorida.</span></div><button type="button" role="switch" aria-checked={useGoogleAvatar} aria-label="Usar foto do Google" className={`toggle ${useGoogleAvatar?'on':''}`} onClick={()=>setUseGoogleAvatar(value=>!value)}><span/></button></div>}{!useGoogleAvatar&&<fieldset><legend className="sr-only">Cor do avatar</legend><div className="color-options">{avatarColors.map((c,i)=><label key={c} style={{'--avatar-color':c} as React.CSSProperties}><input type="radio" name="avatarColor" value={c} checked={c===color} onChange={()=>setColor(c)}/><span>{c===color&&<Check size={18}/>}</span><span className="sr-only">{colorNames[i]}</span></label>)}</div></fieldset>}<label className="field-label" htmlFor="username">Nome de usuário</label>{profile&&<p className={`name-change-status ${usernameLocked?'locked':''}`}>{usernameLocked?`Nova troca disponível em ${usernameChangeDate}.`:'Você tem 1 troca de nome disponível. Depois, aguarde 90 dias.'}</p>}<div className={`username-input ${usernameLocked?'locked':''}`}><span>@</span><input id="username" value={username} onChange={e=>{setUsername(e.target.value);setError('');}} autoComplete="username" maxLength={12} minLength={3} pattern="[A-Za-z0-9_]{3,12}" required readOnly={usernameLocked} aria-describedby={usernameChanged?'username-hint':undefined} aria-invalid={usernameChanged&&['taken','invalid'].includes(availability)} placeholder="SeuNome"/></div>{usernameChanged&&<p id="username-hint" className={`field-hint ${availability==='available'?'blue-text':''}`} aria-live="polite">{usernameLocked?'A troca de nome está indisponível no momento.':hints[availability]}</p>}{profile&&<fieldset className="profile-style-group">
    <legend className="field-label">Personalização do perfil</legend>
    <div className="profile-style-tabs" role="group" aria-label="Escolher personalização">
      <button type="button" aria-pressed={styleTab==='name'} onClick={()=>setStyleTab('name')}>Cor nome</button>
      <button type="button" aria-pressed={styleTab==='frame'} onClick={()=>setStyleTab('frame')}>Moldura</button>
      <button type="button" aria-pressed={styleTab==='font'} onClick={()=>setStyleTab('font')}>Fonte</button>
    </div>
    {styleTab!=='font'&&!canStyle&&<p className="pass-style-locked-note"><LockKeyhole size={14} aria-hidden="true"/> Abra caixas na Loja para desbloquear estilos.</p>}
    {styleTab!=='font'&&canStyle&&!allStylesUnlocked&&<p className="pass-style-locked-note">Seus estilos desbloqueados</p>}
    <div className="pass-style-options">
      {styleTab==='font'?<button type="button" className="pass-style-option" aria-pressed={true} aria-label="Fonte Normal"><span className="pass-name-preview">@{username||'Nome'}</span><span className="pass-style-option-label">Normal</span></button>:styleTab==='name'?
        visibleNameStyles.map(([style,label])=>{
          const locked=!canStyle&&style!=='none';
          const category=styleCategory(style);
          return <button type="button" key={style} className={'pass-style-option '+(category?'style-category-'+category+' ':'')+(locked?'is-locked':'')} aria-pressed={nameStyle===style} aria-label={'Nome '+(category?categoryName[category]+' · ':'')+label+(locked?', exclusivo Premium':'')} disabled={locked} onClick={()=>setNameStyle(style)}>
            <span className={'pass-name-preview '+(locked?'':'pass-name-'+style)}>@{username||'Nome'}</span>
            <span className="pass-style-option-label">{label}</span>
            {locked&&<LockKeyhole size={15} aria-hidden="true"/>}
          </button>;
        }):
        visibleFrameStyles.map(([style,label])=>{
          const locked=!canStyle&&style!=='none';
          const category=styleCategory(style);
          const frameLabel=style==='none'?'Sem moldura':label;
          return <button type="button" key={style} className={'pass-style-option frame-option '+(category?'style-category-'+category+' ':'')+(locked?'is-locked':'')} aria-pressed={borderStyle===style} aria-label={'Moldura '+(category?categoryName[category]+' · ':'')+frameLabel+(locked?', exclusivo Premium':'')} disabled={locked} onClick={()=>setBorderStyle(style)}>
            <Avatar name={username||'?'} color={color} imageUrl={useGoogleAvatar?profile.avatarUrl:null} borderStyle={locked?'none':style}/>
            <span className="pass-style-option-label">{frameLabel}</span>
            {locked&&<LockKeyhole size={15} aria-hidden="true"/>}
          </button>;
        })}
    </div>
  </fieldset>}{error&&<ErrorNotice message={error}/>}<button className="primary-button w-full" disabled={busy||availability!=='available'}>{busy?<><LoaderCircle size={18} className="spin"/> Salvando…</>:profile?'Salvar alterações':'Começar minha jornada'}</button></form>;
}
