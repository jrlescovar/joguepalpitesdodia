/** Match the client's persisted session without downloading the SDK for a new visitor. */
export function authStorageKey(url: string) {
  try { return `sb-${new URL(url).hostname.split('.')[0]}-auth-token`; }
  catch { return null; }
}

export function needsAuthRestore(url: URL, storage: Pick<Storage, 'getItem'>, key: string | null) {
  if (url.searchParams.has('code') || url.searchParams.has('error') || url.searchParams.has('error_description')
    || /(?:^#|&)(?:access_token|refresh_token|error)=/.test(url.hash)) return true;
  if (!key) return true;
  try { return storage.getItem(key) !== null; }
  catch { return true; }
}
