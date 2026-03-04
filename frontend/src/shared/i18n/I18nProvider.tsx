import { useMemo, useState, type ReactNode } from 'react';

import { I18nContext, type I18nContextValue } from './i18nContext';
import type { AppLocale } from './messages';
import { messages } from './messages';

const LOCALE_KEY = 'app_locale';

function detectInitialLocale(): AppLocale {
  const stored = localStorage.getItem(LOCALE_KEY);
  if (stored === 'en' || stored === 'ru' || stored === 'uk') {
    return stored;
  }
  const browser = navigator.language.toLowerCase();
  if (browser.startsWith('ru')) return 'ru';
  if (browser.startsWith('uk')) return 'uk';
  return 'en';
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<AppLocale>(detectInitialLocale);

  const value = useMemo<I18nContextValue>(
    () => ({
      locale,
      setLocale: (next) => {
        setLocaleState(next);
        localStorage.setItem(LOCALE_KEY, next);
      },
      t: (key) => messages[locale][key] ?? messages.en[key] ?? key,
    }),
    [locale],
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}
