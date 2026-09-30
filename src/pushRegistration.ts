/** A new worker must be active before PushManager.subscribe can run. */
export async function activePushRegistration(container: Pick<ServiceWorkerContainer, 'register' | 'ready'>) {
  const registered = await container.register('/push-sw.js');
  if (registered.active?.state === 'activated') return registered;
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const ready = await Promise.race([
      container.ready,
      new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error('A ativação dos avisos demorou. Tente novamente.')), 15000); }),
    ]);
    if (ready.scope !== registered.scope) throw new Error('Não foi possível ativar os avisos neste aparelho. Tente novamente.');
    return ready;
  } finally { clearTimeout(timer); }
}
