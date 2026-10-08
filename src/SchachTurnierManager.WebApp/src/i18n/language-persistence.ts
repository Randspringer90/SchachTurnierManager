/** Apply an explicitly selected supported language; persistence remains optional. */
export type LanguageSaveResult = 'ignored' | 'stored' | 'session-only';

/** Keep an unsaved explicit choice through restoration and queued stale events. */
export function acceptStoredLanguage(
  language: string,
  source: 'storage' | 'restore',
  pending: { stored: string | null } | null,
): boolean {
  return pending === null || (source === 'storage' && language !== pending.stored);
}

export function selectAndStoreLanguage<T extends string>(
  candidate: unknown,
  supported: readonly T[],
  select: (language: T) => void,
  store: (language: T) => void,
): LanguageSaveResult {
  const language = supported.find(value => value === candidate);
  if (language === undefined) return 'ignored';

  // Rendering/state errors must not be misclassified as storage failure.
  select(language);
  try {
    store(language);
    // A successful write is not a promise of permanent browser storage.
    return 'stored';
  } catch {
    // Never expose browser exception text or other stored data to the UI.
    return 'session-only';
  }
}
