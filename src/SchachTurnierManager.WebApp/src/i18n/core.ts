/** Pure i18n primitives. No browser, React, persistence or network side effects. */
export function selectLanguage<T extends string>(
  supported: readonly T[], fallback: T, stored: unknown, preferred: readonly unknown[] = [],
): T {
  if (!supported.includes(fallback)) throw new Error('Unsupported fallback language.');
  for (const candidate of [stored, ...preferred]) {
    if (typeof candidate !== 'string') continue;
    const tag = candidate.trim().toLowerCase();
    // Supported languages use two-letter bases; ignore malformed preference data.
    if (!/^[a-z]{2}(?:[-_][a-z0-9]{2,8})*$/.test(tag)) continue;
    const code = tag.split(/[-_]/, 1)[0];
    const match = supported.find(language => language === code);
    if (match !== undefined) return match;
  }
  return fallback;
}

/** Storage and navigator access may independently be unavailable or throw. */
export function detectLanguage<T extends string>(
  supported: readonly T[], fallback: T,
  readStored: () => unknown, readPreferred: () => readonly unknown[],
): T {
  let stored: unknown;
  let preferred: readonly unknown[] = [];
  try { stored = readStored(); } catch { /* Persistence is optional. */ }
  try {
    const result = readPreferred();
    if (Array.isArray(result)) preferred = result;
  } catch { /* Browser preferences are optional. */ }
  return selectLanguage(supported, fallback, stored, preferred);
}

/** Replacements are literal and single-pass, never replacement-string syntax. */
export function translateText(
  key: string,
  dictionaries: readonly Readonly<Record<string, unknown>>[],
  params?: Readonly<Record<string, string | number>>,
): string {
  let template = key;
  for (const dictionary of dictionaries) {
    if (!Object.prototype.hasOwnProperty.call(dictionary, key)) continue;
    const candidate = dictionary[key];
    if (typeof candidate === 'string' && candidate.trim().length > 0) {
      template = candidate;
      break;
    }
  }
  if (!params) return template;
  return template.replace(/\{([^{}]+)\}/g, (placeholder: string, name: string) => {
    if (!Object.prototype.hasOwnProperty.call(params, name)) return placeholder;
    const value = params[name];
    return typeof value === 'string' || typeof value === 'number' ? String(value) : placeholder;
  });
}
