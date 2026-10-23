import { useEffect, useState, type FormEvent } from 'react';
import { Box, Check, Search, Sparkles, Trash2, Users } from 'lucide-react';
import { call, errorMessage } from './backend';
import { avatarColors, colorNames, type AdminPassGrant, type Profile } from './types';
import { Avatar, ErrorNotice, Modal } from './components';
import AdminPickCorrection from './AdminPickCorrection';
import AdminTournamentPickCorrection from './AdminTournamentPickCorrection';

type Fields = { username: string; avatarColor: string; level: string; xp: string; rankPoints: string; green: string; red: string; greenStreakCurrent: string; greenStreakMax: string };
const numericFields = [
  { key: 'level', label: 'Nível', min: 1 },
  { key: 'xp', label: 'XP no nível atual', min: 0 },
  { key: 'rankPoints', label: 'PontosRank', min: 0 },
  { key: 'green', label: 'Greens', min: 0 },
  { key: 'red', label: 'Reds', min: 0 },
  { key: 'greenStreakCurrent', label: 'Greens seguidos', min: 0 },
  { key: 'greenStreakMax', label: 'Maior sequência de greens', min: 0 },
] as const;

function fieldsFrom(profile: Profile): Fields {
  return { username: profile.username, avatarColor: profile.avatarColor, level: String(profile.level), xp: String(profile.xp), rankPoints: String(profile.rankPoints ?? 0), green: String(profile.green), red: String(profile.red), greenStreakCurrent: String(profile.greenStreakCurrent), greenStreakMax: String(profile.greenStreakMax) };
}

export default function AdminProfileEditor({ initialSearch }: { initialSearch?: string } = {}) {
  const [search, setSearch] = useState('');
  const [profile, setProfile] = useState<Profile | null>(null);
  const [fields, setFields] = useState<Fields | null>(null);
  const [review, setReview] = useState<Fields | null>(null);
  const [removePhotoReview, setRemovePhotoReview] = useState(false);
  const [passGrant, setPassGrant] = useState<AdminPassGrant | null>(null);
  const [boxBalance,setBoxBalance]=useState<number|null>(null);
  const [boxQuantity,setBoxQuantity]=useState('1');
  const [halloweenBoxBalance,setHalloweenBoxBalance]=useState<number|null>(null);
  const [halloweenBoxQuantity,setHalloweenBoxQuantity]=useState('1');
  const [fontBoxBalance,setFontBoxBalance]=useState<number|null>(null);
  const [fontBoxQuantity,setFontBoxQuantity]=useState('1');
  const [boxGrantReview,setBoxGrantReview]=useState<'classic'|'halloween'|'font'|null>(null);
  const [legendaryQuantity,setLegendaryQuantity]=useState('1');
  const [legendaryReview,setLegendaryReview]=useState(false);
  const [grantDays, setGrantDays] = useState('30');
  const [grantReview, setGrantReview] = useState<'activate' | 'disable' | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  async function find(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); await loadPlayer(search);
  }
  useEffect(() => { if (initialSearch) void loadPlayer(initialSearch); }, [initialSearch]);
  async function loadPlayer(query: string) {
    setBusy(true); setError(''); setSuccess(''); setProfile(null); setFields(null); setReview(null); setPassGrant(null); setBoxBalance(null); setHalloweenBoxBalance(null);setFontBoxBalance(null);
    try {
      const found = await call<Profile>('getAdminProfile', { search: query });
      setProfile(found); setFields(fieldsFrom(found));
      const [grant,balance,halloweenBalance,fontBalance]=await Promise.all([call<AdminPassGrant>('getAdminPassGrant', { uid: found.uid }),call<number>('getAdminBoxBalance',{uid:found.uid}),call<number>('getAdminHalloweenBoxBalance',{uid:found.uid}),call<number>('getAdminFontBoxBalance',{uid:found.uid})]);
      setPassGrant(grant);setBoxBalance(balance);setHalloweenBoxBalance(halloweenBalance);setFontBoxBalance(fontBalance);
    } catch (cause) { setError(errorMessage(cause)); } finally { setBusy(false); }
  }

  async function commit(next: Fields) {
    if (!profile) return;
    setBusy(true); setError(''); setSuccess('');
    try {
      await call('adminUpdateProfile', {
        uid: profile.uid, username: next.username, avatarColor: next.avatarColor,
        level: Number(next.level), xp: Number(next.xp), rankPoints: Number(next.rankPoints), green: Number(next.green), red: Number(next.red),
        greenStreakCurrent: Number(next.greenStreakCurrent), greenStreakMax: Number(next.greenStreakMax),
      });
      const updated = await call<Profile>('getAdminProfile', { search: `#${profile.playerId}` });
      setProfile(updated); setFields(fieldsFrom(updated)); setReview(null);
      setSuccess('Perfil do jogador atualizado.');
    } catch (cause) { setError(errorMessage(cause)); } finally { setBusy(false); }
  }

  async function removePhoto() {
    if (!profile) return;
    setBusy(true); setError(''); setSuccess('');
    try {
      await call('adminRemoveProfilePhoto', { uid: profile.uid });
      setProfile({ ...profile, avatarUrl: null }); setRemovePhotoReview(false);
      setSuccess('Foto removida. Ela será atualizada no próximo login Google do jogador.');
    } catch (cause) { setError(errorMessage(cause)); } finally { setBusy(false); }
  }

  async function setFreePremium() {
    if (!profile || !grantReview) return;
    setBusy(true); setError(''); setSuccess('');
    try {
      const days = grantReview === 'disable' ? 0 : Number(grantDays);
      const updated = await call<AdminPassGrant>('setAdminPassGrant', { uid: profile.uid, days });
      setPassGrant(updated); setGrantReview(null);
      setSuccess(days ? `Premium enviado ao correio: ${days} ${days === 1 ? 'dia' : 'dias'}.` : 'Premium gratuito desativado.');
    } catch (cause) { setError(errorMessage(cause)); } finally { setBusy(false); }
  }

  async function grantBoxes(){
    if(!profile||!boxGrantReview)return;
    setBusy(true);setError('');setSuccess('');
    try{
      const themed=boxGrantReview==='halloween';
      const fonts=boxGrantReview==='font';
      const quantity=Number(fonts?fontBoxQuantity:themed?halloweenBoxQuantity:boxQuantity);
      const balance=await call<number>(fonts?'grantFontBoxes':themed?'grantHalloweenBoxes':'grantBoxes',{uid:profile.uid,quantity});
      if(fonts)setFontBoxBalance(balance);else if(themed)setHalloweenBoxBalance(balance);else setBoxBalance(balance);
      setBoxGrantReview(null);
      setSuccess(`${quantity} ${quantity===1?'caixa enviada ao correio':'caixas enviadas ao correio'} ${themed?'de Halloween ':''}a ${profile.username}.`);
    }catch(cause){setError(errorMessage(cause));}finally{setBusy(false);}
  }

  async function grantLegendary(){if(!profile||busy)return;setBusy(true);setError('');try{await call('grantLegendaryDrops',{uid:profile.uid,quantity:Number(legendaryQuantity)});setLegendaryReview(false);setSuccess('Caixas lendárias enviadas ao correio de '+profile.username+'.');}catch(e){setError(errorMessage(e));}finally{setBusy(false);}}
  function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!profile || !fields) return;
    const original = fieldsFrom(profile);
    if ((Object.keys(fields) as (keyof Fields)[]).every(key => original[key] === fields[key])) {
      setSuccess('Nenhuma alteração para salvar.');
      return;
    }
    const competitiveChange = numericFields.some(({ key }) => original[key] !== fields[key]);
    if (competitiveChange) { setError(''); setReview({ ...fields }); }
    else void commit(fields);
  }

  const original = profile ? fieldsFrom(profile) : null;
  const changes = review && original ? ([
    { key: 'username', label: 'Nome de usuário' },
    { key: 'avatarColor', label: 'Cor do avatar' },
    ...numericFields,
  ] as { key: keyof Fields; label: string }[]).filter(({ key }) => review[key] !== original[key]) : [];

  return <section className="card admin-profile-card">
    <h2><Users size={19}/> {profile ? `Administrar ${profile.username}` : 'Painel do jogador'}</h2>
    <div className="admin-profile-body">
      {!initialSearch && <form onSubmit={find}>
        <label className="field-label" htmlFor="admin-player-search">Nome de usuário ou ID</label>
        <div className="admin-search-row"><input id="admin-player-search" value={search} onChange={event => setSearch(event.target.value)} placeholder="jogador ou #1000002" required/><button className="secondary-button" disabled={busy}><Search size={16}/>Buscar</button></div>
      </form>}
      {busy && !profile && <p role="status">Carregando jogador…</p>}
      {profile && fields && <form onSubmit={save} className="admin-profile-form">
        <div className="admin-player-preview"><Avatar name={fields.username || '?'} color={fields.avatarColor} imageUrl={profile.avatarUrl}/><div><strong>{profile.username}</strong><span>#{profile.playerId}</span></div>{profile.avatarUrl&&<button type="button" className="text-button admin-remove-photo" onClick={()=>setRemovePhotoReview(true)}><Trash2 size={16}/>Remover foto</button>}</div>
        <label className="field-label" htmlFor="admin-username">Nome de usuário</label>
        <input id="admin-username" value={fields.username} onChange={event => setFields({ ...fields, username: event.target.value })} minLength={3} maxLength={12} pattern="[A-Za-z0-9_]{3,12}" required/>
        <fieldset><legend className="field-label">Cor do avatar</legend><div className="color-options">{avatarColors.map((color, index) => <label key={color} style={{ '--avatar-color': color } as React.CSSProperties}><input type="radio" name="adminAvatarColor" value={color} checked={fields.avatarColor === color} onChange={() => setFields({ ...fields, avatarColor: color })}/><span>{fields.avatarColor === color && <Check size={18}/>}</span><span className="sr-only">{colorNames[index]}</span></label>)}</div></fieldset>
        <div className="admin-stats-grid">{numericFields.map(({ key, label, min }) => <label key={key}>{label}<input type="number" value={fields[key]} onChange={event => setFields({ ...fields, [key]: event.target.value })} min={min} max={key === 'xp' ? Math.max(0, Number(fields.level) * 15 - 1) : key === 'rankPoints' ? 1000000 : undefined} step={1} required/></label>)}</div>
        <p className="muted text-xs">O XP precisa ser menor que o necessário para o próximo nível. A maior sequência não pode superar o total de greens.</p>
        <button className="primary-button" disabled={busy}>{busy ? 'Salvando…' : 'Salvar perfil do jogador'}</button>
      </form>}
      {profile && <AdminPickCorrection profile={profile} onCorrect={async () => {
        const updated = await call<Profile>('getAdminProfile', { search: `#${profile.playerId}` });
        setProfile(updated); setFields(fieldsFrom(updated));
      }}/>}
      {profile && <AdminTournamentPickCorrection key={profile.uid} profile={profile}/>}
      {profile && passGrant && <section className="admin-pass-card" aria-label="Premium do jogador">
        <div className="admin-pass-heading"><Sparkles size={19}/><strong>Premium do jogador</strong></div>
        <p>{passGrant.paidActive ? `Apoiador comprado ativo até ${new Date(passGrant.paidEndsAt!).toLocaleDateString('pt-BR', { timeZone: 'America/Sao_Paulo' })}.` : 'Sem Apoiador comprado ativo.'}</p>
        <p>{passGrant.freeActive ? `Premium gratuito ativo até ${new Date(passGrant.freeEndsAt!).toLocaleDateString('pt-BR', { timeZone: 'America/Sao_Paulo' })}.` : 'Sem Premium gratuito ativo.'}</p>
        <label className="field-label" htmlFor="admin-grant-days">Duração do Premium gratuito (dias)</label>
        <div className="admin-pass-actions"><input id="admin-grant-days" type="number" min="1" max="3650" step="1" value={grantDays} onChange={event => setGrantDays(event.target.value)}/><button type="button" className="secondary-button" disabled={busy || !Number.isInteger(Number(grantDays)) || Number(grantDays) < 1 || Number(grantDays) > 3650} onClick={() => setGrantReview('activate')}>{passGrant.freeActive ? 'Definir novo prazo' : 'Ativar Premium gratuito'}</button></div>
        {passGrant.freeActive && <button type="button" className="text-button" disabled={busy} onClick={() => setGrantReview('disable')}>Desativar Premium gratuito</button>}
        <p className="muted text-xs">O prazo começa quando o jogador recebe no correio. O período comprado, se existir, não será alterada. Caixas devem ser concedidas separadamente abaixo.</p>
      </section>}
      {profile&&boxBalance!==null&&<section className="admin-pass-card" aria-label="Caixas do jogador"><div className="admin-pass-heading"><Box size={19}/><strong>Caixas de Personalização</strong></div><p>Saldo disponível: <strong>{boxBalance}</strong></p><label className="field-label" htmlFor="admin-box-quantity">Quantidade para conceder</label><div className="admin-pass-actions"><input id="admin-box-quantity" type="number" min="1" max="100" step="1" value={boxQuantity} onChange={event=>setBoxQuantity(event.target.value)}/><button type="button" className="secondary-button" disabled={busy||!Number.isInteger(Number(boxQuantity))||Number(boxQuantity)<1||Number(boxQuantity)>100} onClick={()=>setBoxGrantReview('classic')}>Conceder caixas</button></div><p className="muted text-xs">A entrega vai para o correio. O jogador recebe antes de abrir.</p></section>}
      {profile&&halloweenBoxBalance!==null&&<section className="admin-pass-card admin-halloween-boxes" aria-label="Caixas de Halloween do jogador"><div className="admin-pass-heading"><Box size={19}/><strong>Caixas de Halloween</strong></div><p>Saldo disponível: <strong>{halloweenBoxBalance}</strong></p><label className="field-label" htmlFor="admin-halloween-box-quantity">Quantidade para conceder</label><div className="admin-pass-actions"><input id="admin-halloween-box-quantity" type="number" min="1" max="100" step="1" value={halloweenBoxQuantity} onChange={event=>setHalloweenBoxQuantity(event.target.value)}/><button type="button" className="secondary-button" disabled={busy||!Number.isInteger(Number(halloweenBoxQuantity))||Number(halloweenBoxQuantity)<1||Number(halloweenBoxQuantity)>100} onClick={()=>setBoxGrantReview('halloween')}>Conceder caixas de Halloween</button></div><p className="muted text-xs">Estas caixas abrem somente itens do evento.</p></section>}
      {profile&&fontBoxBalance!==null&&<section className="admin-pass-card admin-font-boxes" aria-label="Caixas de Fontes do jogador"><div className="admin-pass-heading"><Box size={19}/><strong>Caixas de Fontes</strong></div><p>Saldo disponível: <strong>{fontBoxBalance}</strong></p><label className="field-label" htmlFor="admin-font-box-quantity">Quantidade para conceder</label><div className="admin-pass-actions"><input id="admin-font-box-quantity" type="number" min="1" max="100" step="1" value={fontBoxQuantity} onChange={event=>setFontBoxQuantity(event.target.value)}/><button type="button" className="secondary-button" disabled={busy||!Number.isInteger(Number(fontBoxQuantity))||Number(fontBoxQuantity)<1||Number(fontBoxQuantity)>100} onClick={()=>setBoxGrantReview('font')}>Conceder caixas de Fontes</button></div><p className="muted text-xs">Estas caixas abrem somente fontes de nome.</p></section>}
      {profile&&<section className="admin-pass-card" aria-label="Caixas lendárias do jogador"><strong>Caixa Lendária</strong><label className="field-label" htmlFor="admin-legendary-quantity">Quantidade para conceder</label><div className="admin-pass-actions"><input id="admin-legendary-quantity" type="number" min="1" max="100" step="1" value={legendaryQuantity} onChange={e=>setLegendaryQuantity(e.target.value)}/><button type="button" className="secondary-button" disabled={busy||!Number.isInteger(Number(legendaryQuantity))||Number(legendaryQuantity)<1||Number(legendaryQuantity)>100} onClick={()=>setLegendaryReview(true)}>Conceder caixas lendárias</button></div><p className="muted text-xs">Enviado ao correio. Cada caixa garante um item lendário.</p></section>}
      {error && !review && <ErrorNotice message={error}/>}
      {success && <p className="success-message" role="status"><Check size={18}/>{success}</p>}
    </div>
    <Modal className="admin-dialog" open={legendaryReview} onOpenChange={v=>{if(!busy)setLegendaryReview(v);}} title="Conceder caixas lendárias?" description={legendaryQuantity+' caixas lendárias para '+profile?.username}>{error&&<ErrorNotice message={error}/>}<div className="admin-review-actions"><button className="secondary-button" disabled={busy} onClick={()=>setLegendaryReview(false)}>Voltar</button><button className="primary-button" disabled={busy} onClick={()=>void grantLegendary()}>Confirmar concessão</button></div></Modal>
    <Modal className="admin-dialog" open={Boolean(review)} onOpenChange={open => { if (!open && !busy) setReview(null); }} title="Revisar alteração do jogador" description={`Confira os dados antes de alterar o ranking e a experiência de #${profile?.playerId ?? ''}.`}>
      <div className="admin-change-list">{changes.map(({ key, label }) => <div className="admin-change-row" key={key}><span>{label}</span><strong>{key === 'avatarColor' ? `${colorNames[avatarColors.indexOf(original?.avatarColor ?? '')] ?? 'Atual'} → ${colorNames[avatarColors.indexOf(review?.avatarColor ?? '')] ?? 'Nova'}` : `${original?.[key]} → ${review?.[key]}`}</strong></div>)}</div>
      {error && <ErrorNotice message={error}/>}
      <div className="admin-review-actions"><button type="button" className="secondary-button" onClick={() => setReview(null)} disabled={busy}>Voltar</button><button type="button" className="primary-button" onClick={() => review && void commit(review)} disabled={busy}>{busy ? 'Salvando…' : 'Confirmar alteração'}</button></div>
    </Modal>
    <Modal className="admin-dialog" open={removePhotoReview} onOpenChange={open=>{if(!open&&!busy)setRemovePhotoReview(false);}} title="Remover foto do jogador?" description="O avatar voltará para a inicial colorida. A foto atual do Google será sincronizada quando o jogador entrar novamente.">
      {error&&<ErrorNotice message={error}/>}<div className="admin-review-actions"><button type="button" className="secondary-button" onClick={()=>setRemovePhotoReview(false)} disabled={busy}>Cancelar</button><button type="button" className="primary-button" onClick={()=>void removePhoto()} disabled={busy}>{busy?'Removendo…':'Remover foto'}</button></div>
    </Modal>
    <Modal className="admin-dialog" open={Boolean(grantReview)} onOpenChange={open=>{if(!open&&!busy)setGrantReview(null);}} title={grantReview === 'disable' ? 'Desativar Premium gratuito?' : 'Ativar Premium gratuito?'} description={grantReview === 'disable' ? 'Os benefícios gratuitos terminam imediatamente. Um período comprado ativo continua valendo.' : `O jogador terá Premium por ${grantDays} ${Number(grantDays) === 1 ? 'dia' : 'dias'}, a partir de agora. Nenhuma caixa será concedida automaticamente.`}>
      <p className="confirm-selection">{profile?.username}</p>
      {error&&<ErrorNotice message={error}/>}
      <div className="admin-review-actions"><button type="button" className="secondary-button" onClick={()=>setGrantReview(null)} disabled={busy}>Voltar</button><button type="button" className="primary-button" onClick={()=>void setFreePremium()} disabled={busy}>{busy?'Salvando…':grantReview === 'disable'?'Desativar':'Confirmar Premium'}</button></div>
    </Modal>
    <Modal className="admin-dialog" open={Boolean(boxGrantReview)} onOpenChange={open=>{if(!open&&!busy)setBoxGrantReview(null);}} title={boxGrantReview==='font'?'Conceder caixas de fontes?':boxGrantReview==='halloween'?'Conceder caixas de Halloween?':'Conceder caixas?'} description={`Adicionar ${boxGrantReview==='font'?fontBoxQuantity:boxGrantReview==='halloween'?halloweenBoxQuantity:boxQuantity} ${Number(boxGrantReview==='font'?fontBoxQuantity:boxGrantReview==='halloween'?halloweenBoxQuantity:boxQuantity)===1?'caixa':'caixas'} ${boxGrantReview==='font'?'de fontes ':boxGrantReview==='halloween'?'de Halloween ':''}ao saldo de ${profile?.username??'jogador'}.`}><p className="confirm-selection">{profile?.username} · #{profile?.playerId}</p>{error&&<ErrorNotice message={error}/>}<div className="admin-review-actions"><button type="button" className="secondary-button" onClick={()=>setBoxGrantReview(null)} disabled={busy}>Voltar</button><button type="button" className="primary-button" onClick={()=>void grantBoxes()} disabled={busy}>{busy?'Concedendo…':'Confirmar concessão'}</button></div></Modal>
  </section>;
}

