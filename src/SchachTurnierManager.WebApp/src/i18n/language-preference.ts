/** Synchronize the existing language preference without writing storage or reloading. */
type PreferenceWindow = Pick<Window, 'localStorage' | 'addEventListener' | 'removeEventListener'>;

export function subscribeStoredLanguage<T extends string>(
  target: PreferenceWindow | undefined,
  key: string,
  supported: readonly T[],
  onLanguage: (language: T) => void,
): () => void {
  if (!target) return () => {};
  const allowed = [...supported];
  let active = true;

  function reconcile(event?: StorageEvent): void {
    if (!active) return;
    let current: string | null;
    try {
      // Re-read live state: queued events may describe an older preference.
      if (event && event.key !== key && event.key !== null) return;
      const storage = target!.localStorage;
      if (event && event.storageArea !== storage) return;
      current = storage.getItem(key);
    } catch {
      // Blocked storage is optional. Keep the current session language.
      return;
    }
    const language = allowed.find(value => value === current);
    // Removal, clear, unknown values and foreign sessionStorage never force a language.
    if (language !== undefined) onLanguage(language);
  }

  const onStorage = (event: StorageEvent) => reconcile(event);
  const onPageShow = () => reconcile();
  const dispose = () => {
    if (!active) return;
    active = false;
    target.removeEventListener('storage', onStorage);
    target.removeEventListener('pageshow', onPageShow);
  };
  try {
    target.addEventListener('storage', onStorage);
    target.addEventListener('pageshow', onPageShow);
    // Close the gap between useState initialization and effect installation.
    reconcile();
  } catch (failure) {
    dispose();
    throw failure;
  }
  return dispose;
}
