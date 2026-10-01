import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { de, type Messages } from './locales/de';
import { en } from './locales/en';
import { es } from './locales/es';
import { fr } from './locales/fr';
import { it } from './locales/it';
import { pt } from './locales/pt';
import { nl } from './locales/nl';
import { pl } from './locales/pl';
import { cs } from './locales/cs';
import { sv } from './locales/sv';
import { da } from './locales/da';
import { hu } from './locales/hu';
import { ru } from './locales/ru';
import { uk } from './locales/uk';
import { tr } from './locales/tr';
import { ar } from './locales/ar';
import { zh } from './locales/zh';
import { ja } from './locales/ja';

export type LanguageCode =
  | 'de' | 'en' | 'es' | 'fr' | 'it' | 'pt' | 'nl' | 'pl' | 'cs'
  | 'sv' | 'da' | 'hu' | 'ru' | 'uk' | 'tr' | 'ar' | 'zh' | 'ja';

type LanguageInfo = {
  code: LanguageCode;
  /** Sprachname in der eigenen Sprache (für den Umschalter). */
  nativeName: string;
  dictionary: Partial<Messages>;
  rtl?: boolean;
};

export const LANGUAGES: readonly LanguageInfo[] = [
  { code: 'de', nativeName: 'Deutsch', dictionary: de },
  { code: 'en', nativeName: 'English', dictionary: en },
  { code: 'es', nativeName: 'Español', dictionary: es },
  { code: 'fr', nativeName: 'Français', dictionary: fr },
  { code: 'it', nativeName: 'Italiano', dictionary: it },
  { code: 'pt', nativeName: 'Português', dictionary: pt },
  { code: 'nl', nativeName: 'Nederlands', dictionary: nl },
  { code: 'pl', nativeName: 'Polski', dictionary: pl },
  { code: 'cs', nativeName: 'Čeština', dictionary: cs },
  { code: 'sv', nativeName: 'Svenska', dictionary: sv },
  { code: 'da', nativeName: 'Dansk', dictionary: da },
  { code: 'hu', nativeName: 'Magyar', dictionary: hu },
  { code: 'ru', nativeName: 'Русский', dictionary: ru },
  { code: 'uk', nativeName: 'Українська', dictionary: uk },
  { code: 'tr', nativeName: 'Türkçe', dictionary: tr },
  { code: 'ar', nativeName: 'العربية', dictionary: ar, rtl: true },
  { code: 'zh', nativeName: '中文', dictionary: zh },
  { code: 'ja', nativeName: '日本語', dictionary: ja },
];

const STORAGE_KEY = 'stm.language';

function detectInitialLanguage(): LanguageCode {
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY);
    if (stored && LANGUAGES.some(l => l.code === stored)) {
      return stored as LanguageCode;
    }
  } catch {
    // localStorage kann in Sonderfällen (z. B. blockierte Cookies) fehlen.
  }
  const browser = (navigator.language || 'de').slice(0, 2).toLowerCase();
  return LANGUAGES.some(l => l.code === browser) ? (browser as LanguageCode) : 'de';
}

export type TranslateFn = (key: keyof Messages, params?: Record<string, string | number>) => string;

type I18nContextValue = {
  lang: LanguageCode;
  setLang: (lang: LanguageCode) => void;
  t: TranslateFn;
};

const I18nContext = createContext<I18nContextValue | null>(null);

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLangState] = useState<LanguageCode>(detectInitialLanguage);

  const setLang = (next: LanguageCode) => {
    setLangState(next);
    try {
      window.localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // Persistenz ist optional; die Sprache gilt dann nur für diese Sitzung.
    }
  };

  useEffect(() => {
    const info = LANGUAGES.find(l => l.code === lang);
    document.documentElement.lang = lang;
    document.documentElement.dir = info?.rtl ? 'rtl' : 'ltr';
  }, [lang]);

  const value = useMemo<I18nContextValue>(() => {
    const dictionary = LANGUAGES.find(l => l.code === lang)?.dictionary ?? de;
    const t: TranslateFn = (key, params) => {
      let text = dictionary[key] ?? en[key] ?? de[key];
      if (params) {
        for (const [name, replacement] of Object.entries(params)) {
          text = text.replaceAll(`{${name}}`, String(replacement));
        }
      }
      return text;
    };
    return { lang, setLang, t };
  }, [lang]);

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): I18nContextValue {
  const ctx = useContext(I18nContext);
  if (!ctx) {
    throw new Error('useI18n muss innerhalb von <I18nProvider> verwendet werden.');
  }
  return ctx;
}

export function LanguageSwitcher() {
  const { lang, setLang, t } = useI18n();
  return (
    <label className="language-switcher">
      <span>{t('language.label')}</span>
      <select value={lang} onChange={e => setLang(e.target.value as LanguageCode)}>
        <optgroup label={t('language.demoGroup')}>
          {LANGUAGES.filter(l => l.code === 'de' || l.code === 'en').map(l => (
            <option key={l.code} value={l.code}>{l.nativeName}</option>
          ))}
        </optgroup>
        <optgroup label={t('language.previewGroup')}>
          {LANGUAGES.filter(l => l.code !== 'de' && l.code !== 'en').map(l => (
            <option key={l.code} value={l.code}>{l.nativeName}</option>
          ))}
        </optgroup>
      </select>
    </label>
  );
}
