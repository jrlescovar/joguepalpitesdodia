// Share simultaneous reads. Only explicitly selected data survives completion.
export class ReadRequests {
  private pending = new Map<string, Promise<unknown>>();
  private cached = new Map<string, { value: unknown; expires: number }>();
  private generation = 0;

  clear() {
    this.generation += 1;
    this.pending.clear();
    this.cached.clear();
  }

  run<T>(key: string, read: () => Promise<T>, ttl = 0): Promise<T> {
    const cached = this.cached.get(key);
    if (cached && cached.expires > Date.now()) return Promise.resolve(cached.value as T);
    this.cached.delete(key);
    const pending = this.pending.get(key);
    if (pending) return pending as Promise<T>;
    const generation = this.generation;
    const request = Promise.resolve().then(read);
    this.pending.set(key, request);
    void request.then(value => {
      if (generation !== this.generation) return;
      this.pending.delete(key);
      if (ttl > 0) this.cached.set(key, { value, expires: Date.now() + ttl });
    }, () => {
      if (generation === this.generation) this.pending.delete(key);
    });
    return request;
  }
}
