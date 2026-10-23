const recoveryKey = 'palpites-chunk-recovery';
const recoveryWindow = 60_000;

/** A stale lazy chunk gets one fresh page request; a repeated failure shows recovery UI. */
export function installChunkRecovery() {
  const handle = (event: Event) => {
    event.preventDefault();
    let retry = false;
    try {
      const previous = Number(sessionStorage.getItem(recoveryKey));
      retry = !previous || Date.now() - previous > recoveryWindow;
      if (retry) sessionStorage.setItem(recoveryKey, String(Date.now()));
    } catch { /* Without storage, do not risk an automatic reload loop. */ }
    if (retry) location.reload();
    else window.dispatchEvent(new Event('palpites:chunk-unavailable'));
  };
  window.addEventListener('vite:preloadError', handle);
  return () => window.removeEventListener('vite:preloadError', handle);
}
