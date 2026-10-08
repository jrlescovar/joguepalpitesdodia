// Collapse bursts into one follow-up refresh, without losing changes made mid-flight.
export function refreshQueue(run: () => Promise<void>) {
  let pending: Promise<void> | null = null;
  let again = false;
  return () => {
    if (pending) { again = true; return pending; }
    const execute = async () => {
      do { again = false; await run(); } while (again);
    };
    const request = execute();
    pending = request;
    const clear = () => { if (pending === request) pending = null; };
    void request.then(clear, clear);
    return request;
  };
}
