import { useState, type FormEvent } from 'react';
import { Check, Search, Trash2, Users } from 'lucide-react';
import { call, errorMessage } from './backend';
import { avatarColors, colorNames, type Profile } from './types';
import { Avatar, ErrorNotice, Modal } from './components';

type Fields = { username: string; avatarColor: string; level: string; xp: string; green: string; red: string; greenStreakCurrent: string; greenStreakMax: string };
const numericFields = [
  { key: 'level', label: 'Nível', min: 1 },
  { key: 'xp', label: 'XP no nível atual', min: 0 },
  { key: 'green', label: 'Greens', min: 0 },
  { key: 'red', label: 'Reds', min: 0 },
  { key: 'greenStreakCurrent', label: 'Greens seguidos', min: 0 },
  { key: 'greenStreakMax', label: 'Maior sequência de greens', min: 0 },
] as const;

function fieldsFrom(profile: Profile): Fields {
  return { username: profile.username, avatarColor: profile.avatarColor, level: String(profile.level), xp: String(profile.xp), green: String(profile.green), red: String(profile.red), greenStreakCurrent: String(profile.greenStreakCurrent), greenStreakMax: String(profile.greenStreakMax) };
}

export default function AdminProfileEditor() {
  const [search, setSearch] = useState('');
  const [profile, setProfile] = useState<Profile | null>(null);
  const [fields, setFields] = useState<Fields | null>(null);
  const [review, setReview] = useState<Fields | null>(null);
  const [removePhotoReview, setRemovePhotoReview] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  async function find(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(''); setSuccess(''); setProfile(null); setFields(null); setReview(null);
    try {
      const found = await call<Profile>('getAdminProfile', { search });
      setProfile(found); setFields(fieldsFrom(found));
    } catch (cause) { setError(errorMessage(cause)); } finally { setBusy(false); }
  }

  async function commit(next: Fields) {
    if (!profile) return;
    setBusy(true); setError(''); setSuccess('');
    try {
      await call('adminUpdateProfile', {
        uid: profile.uid, username: next.username, avatarColor: next.avatarColor,
        level: Number(next.level), xp: Number(next.xp), green: Number(next.green), red: Number(next.red),
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

  return <details className="card admin-profile-card">
    <summary><Users size={19}/> Editar perfil de jogador</summary>
    <div className="admin-profile-body">
      <form onSubmit={find}>
        <label className="field-label" htmlFor="admin-player-search">Nome de usuário ou ID</label>
        <div className="admin-search-row"><input id="admin-player-search" value={search} onChange={event => setSearch(event.target.value)} placeholder="@jogador ou #1000002" required/><button className="secondary-button" disabled={busy}><Search size={16}/>Buscar</button></div>
      </form>
      {profile && fields && <form onSubmit={save} className="admin-profile-form">
        <div className="admin-player-preview"><Avatar name={fields.username || '?'} color={fields.avatarColor} imageUrl={profile.avatarUrl}/><div><strong>@{profile.username}</strong><span>#{profile.playerId}</span></div>{profile.avatarUrl&&<button type="button" className="text-button admin-remove-photo" onClick={()=>setRemovePhotoReview(true)}><Trash2 size={16}/>Remover foto</button>}</div>
        <label className="field-label" htmlFor="admin-username">Nome de usuário</label>
        <input id="admin-username" value={fields.username} onChange={event => setFields({ ...fields, username: event.target.value })} minLength={3} maxLength={12} pattern="[A-Za-z0-9_]{3,12}" required/>
        <fieldset><legend className="field-label">Cor do avatar</legend><div className="color-options">{avatarColors.map((color, index) => <label key={color} style={{ '--avatar-color': color } as React.CSSProperties}><input type="radio" name="adminAvatarColor" value={color} checked={fields.avatarColor === color} onChange={() => setFields({ ...fields, avatarColor: color })}/><span>{fields.avatarColor === color && <Check size={18}/>}</span><span className="sr-only">{colorNames[index]}</span></label>)}</div></fieldset>
        <div className="admin-stats-grid">{numericFields.map(({ key, label, min }) => <label key={key}>{label}<input type="number" value={fields[key]} onChange={event => setFields({ ...fields, [key]: event.target.value })} min={min} max={key === 'xp' ? Math.max(0, Number(fields.level) * 15 - 1) : undefined} step={1} required/></label>)}</div>
        <p className="muted text-xs">O XP precisa ser menor que o necessário para o próximo nível. A maior sequência não pode superar o total de greens.</p>
        <button className="primary-button" disabled={busy}>{busy ? 'Salvando…' : 'Salvar perfil do jogador'}</button>
      </form>}
      {error && !review && <ErrorNotice message={error}/>}
      {success && <p className="success-message" role="status"><Check size={18}/>{success}</p>}
    </div>
    <Modal open={Boolean(review)} onOpenChange={open => { if (!open && !busy) setReview(null); }} title="Revisar alteração do jogador" description={`Confira os dados antes de alterar o ranking e a experiência de #${profile?.playerId ?? ''}.`}>
      <div className="admin-change-list">{changes.map(({ key, label }) => <div className="admin-change-row" key={key}><span>{label}</span><strong>{key === 'avatarColor' ? `${colorNames[avatarColors.indexOf(original?.avatarColor ?? '')] ?? 'Atual'} → ${colorNames[avatarColors.indexOf(review?.avatarColor ?? '')] ?? 'Nova'}` : `${original?.[key]} → ${review?.[key]}`}</strong></div>)}</div>
      {error && <ErrorNotice message={error}/>}
      <div className="admin-review-actions"><button type="button" className="secondary-button" onClick={() => setReview(null)} disabled={busy}>Voltar</button><button type="button" className="primary-button" onClick={() => review && void commit(review)} disabled={busy}>{busy ? 'Salvando…' : 'Confirmar alteração'}</button></div>
    </Modal>
    <Modal open={removePhotoReview} onOpenChange={open=>{if(!open&&!busy)setRemovePhotoReview(false);}} title="Remover foto do jogador?" description="O avatar voltará para a inicial colorida. A foto atual do Google será sincronizada quando o jogador entrar novamente.">
      {error&&<ErrorNotice message={error}/>}<div className="admin-review-actions"><button type="button" className="secondary-button" onClick={()=>setRemovePhotoReview(false)} disabled={busy}>Cancelar</button><button type="button" className="primary-button" onClick={()=>void removePhoto()} disabled={busy}>{busy?'Removendo…':'Remover foto'}</button></div>
    </Modal>
  </details>;
}
