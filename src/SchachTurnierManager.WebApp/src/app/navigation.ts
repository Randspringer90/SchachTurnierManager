// Main navigation model. Secondary tabs live behind the `More` entry so the
// primary workflow (overview -> participants -> round -> standings) stays flat.
// Extracted from main.tsx (STM-FE-014).
export const mainTabs = [
  { id: 'overview', labelKey: 'nav.overview', secondary: false },
  { id: 'participants', labelKey: 'nav.participants', secondary: false },
  { id: 'rounds', labelKey: 'nav.round', secondary: false },
  { id: 'standings', labelKey: 'nav.standings', secondary: false },
  { id: 'more', labelKey: 'nav.more', secondary: false },
  { id: 'assistant', labelKey: 'more.assistant', secondary: true },
  { id: 'print', labelKey: 'more.exports', secondary: true },
  { id: 'admin', labelKey: 'more.admin', secondary: true }
] as const;

export type MainTab = typeof mainTabs[number]['id'];

export function isMainTab(value: string | null): value is MainTab {
  return value !== null && mainTabs.some(tab => tab.id === value);
}


