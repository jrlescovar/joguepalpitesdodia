import { useEffect, useState } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { ShieldCheck, X } from 'lucide-react';
import { call } from './backend';
import AdminProfileEditor from './AdminProfileEditor';
import type { Session } from './types';
import './adminWorkspace.css';
export default function ProfileAdminPanel({ playerId }: { playerId: number }) {
  const [allowed, setAllowed] = useState(false);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    let active = true;
    void call<Session>('getSession').then(session => {
      if (active) setAllowed(session.admin);
    }).catch(() => {});
    return () => { active = false; };
  }, []);

  if (!allowed) return null;
  return <Dialog.Root open={open} onOpenChange={setOpen}>
    <Dialog.Trigger className="secondary-button profile-admin-button"><ShieldCheck size={18}/>Administrar jogador</Dialog.Trigger>
    <Dialog.Portal>
      <Dialog.Overlay className="dialog-overlay"/>
      <Dialog.Content className="dialog-content admin-profile-dialog" aria-describedby={undefined}>
        <Dialog.Title className="sr-only">Administrar jogador #{playerId}</Dialog.Title>
        <div className="admin-mode"><AdminProfileEditor key={playerId} initialSearch={`#${playerId}`}/></div>
        <Dialog.Close className="close-button" aria-label="Fechar"><X size={20}/></Dialog.Close>
      </Dialog.Content>
    </Dialog.Portal>
  </Dialog.Root>;
}

