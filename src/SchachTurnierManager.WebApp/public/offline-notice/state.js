/** A browser connectivity hint, never proof that the backend is reachable. */
export function readNetworkHint(target) {
  try {
    const value = target?.navigator?.onLine;
    return value === false ? 'offline' : value === true ? 'online-hint' : 'unknown';
  } catch { return 'unknown'; }
}

export function subscribeNetworkHint(target, changed) {
  if (!target) return () => {};
  let active = true;
  let previous;
  const refresh = () => {
    if (!active) return;
    const next = readNetworkHint(target);
    if (next === previous) return;
    previous = next;
    changed(next);
  };
  const events = ['online', 'offline', 'pageshow'];
  const dispose = () => {
    if (!active) return;
    active = false;
    for (const event of events) target.removeEventListener(event, refresh);
  };
  try {
    for (const event of events) target.addEventListener(event, refresh);
    refresh();
  } catch (error) { dispose(); throw error; }
  return dispose;
}
