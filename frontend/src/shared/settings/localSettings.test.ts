import { beforeEach, describe, expect, it } from 'vitest';

import { hotkeyLabel, readLocalSettings, writeLocalSettings } from './localSettings';

describe('localSettings', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('returns defaults for empty storage', () => {
    const settings = readLocalSettings();
    expect(settings.answerHotkey).toBe('Space');
    expect(settings.volume).toBe(1);
    expect(settings.spectatorCleanViewDefault).toBe(true);
  });

  it('persists updates', () => {
    const saved = writeLocalSettings({
      volume: 0.4,
      answerHotkey: 'KeyB',
      spectatorCleanViewDefault: false,
    });
    expect(saved.volume).toBe(0.4);
    expect(saved.answerHotkey).toBe('KeyB');
    expect(saved.spectatorCleanViewDefault).toBe(false);

    const loaded = readLocalSettings();
    expect(loaded).toEqual(saved);
  });

  it('formats hotkey labels', () => {
    expect(hotkeyLabel('Space')).toBe('Space');
    expect(hotkeyLabel('KeyQ')).toBe('Q');
    expect(hotkeyLabel('Digit8')).toBe('8');
  });
});
