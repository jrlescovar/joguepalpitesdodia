// Schedule after completion so a slow connection never stacks requests.
export function pollWhileVisible(run: () => Promise<boolean>, delay: number, visible: () => boolean) {
  let active = true;
  let timer: ReturnType<typeof setTimeout> | undefined;
  async function tick(initial = false) {
    let keepPolling = true;
    try { if (initial || visible()) keepPolling = await run(); }
    catch { /* The caller reports failures; retain polling for a later retry. */ }
    if (active && keepPolling) timer = setTimeout(() => void tick(), delay);
  }
  void tick(true);
  return () => { active = false; if (timer !== undefined) clearTimeout(timer); };
}
