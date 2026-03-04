export type LocalSettings = {
  volume: number;
  answerHotkey: string;
  spectatorCleanViewDefault: boolean;
};

const KEY_VOLUME = 'setting_volume';
const KEY_ANSWER_HOTKEY = 'setting_answer_hotkey_code';
const KEY_SPECTATOR_CLEAN = 'setting_spectator_clean_default';
const CHANGE_EVENT = 'app-settings-changed';

const defaults: LocalSettings = {
  volume: 1,
  answerHotkey: 'Space',
  spectatorCleanViewDefault: true,
};

function clampVolume(value: number): number {
  if (!Number.isFinite(value)) return defaults.volume;
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

export function readLocalSettings(): LocalSettings {
  const volumeStored = localStorage.getItem(KEY_VOLUME);
  const volumeRaw = volumeStored == null ? defaults.volume : Number(volumeStored);
  const hotkey = localStorage.getItem(KEY_ANSWER_HOTKEY)?.trim() || defaults.answerHotkey;
  const cleanRaw = localStorage.getItem(KEY_SPECTATOR_CLEAN);

  return {
    volume: clampVolume(volumeRaw),
    answerHotkey: hotkey,
    spectatorCleanViewDefault: cleanRaw == null ? defaults.spectatorCleanViewDefault : cleanRaw === 'true',
  };
}

export function writeLocalSettings(patch: Partial<LocalSettings>): LocalSettings {
  const current = readLocalSettings();
  const next: LocalSettings = {
    volume: patch.volume == null ? current.volume : clampVolume(patch.volume),
    answerHotkey: patch.answerHotkey?.trim() || current.answerHotkey,
    spectatorCleanViewDefault:
      patch.spectatorCleanViewDefault == null
        ? current.spectatorCleanViewDefault
        : patch.spectatorCleanViewDefault,
  };

  localStorage.setItem(KEY_VOLUME, String(next.volume));
  localStorage.setItem(KEY_ANSWER_HOTKEY, next.answerHotkey);
  localStorage.setItem(KEY_SPECTATOR_CLEAN, String(next.spectatorCleanViewDefault));
  window.dispatchEvent(new CustomEvent(CHANGE_EVENT));
  return next;
}

export function subscribeLocalSettings(onChange: (settings: LocalSettings) => void): () => void {
  const handler = () => onChange(readLocalSettings());
  window.addEventListener(CHANGE_EVENT, handler);
  window.addEventListener('storage', handler);
  return () => {
    window.removeEventListener(CHANGE_EVENT, handler);
    window.removeEventListener('storage', handler);
  };
}

export function hotkeyLabel(code: string): string {
  if (code === 'Space') return 'Space';
  if (code.startsWith('Key')) return code.slice(3);
  if (code.startsWith('Digit')) return code.slice(5);
  return code;
}
