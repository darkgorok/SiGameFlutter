import { useEffect, useState } from 'react';

import { useI18n } from '../../../shared/i18n/i18nContext';
import { auth } from '../../../shared/firebase/client';
import { readLocalProfile, writeLocalProfile } from '../../../shared/profile/localProfile';
import { hotkeyLabel, readLocalSettings, writeLocalSettings } from '../../../shared/settings/localSettings';
import { gameRepository } from '../../game/data/gameRepository';

export function SettingsPage() {
  const { locale, setLocale, t } = useI18n();
  const uid = auth.currentUser?.uid ?? '';
  const [settings, setSettings] = useState(readLocalSettings);
  const [captureHotkey, setCaptureHotkey] = useState(false);
  const [profileModalOpen, setProfileModalOpen] = useState(false);
  const [profileNickname, setProfileNickname] = useState(readLocalProfile().nickname);
  const [profileAvatarUrl, setProfileAvatarUrl] = useState(readLocalProfile().avatarUrl);
  const [profileBusy, setProfileBusy] = useState(false);
  const [profileError, setProfileError] = useState<string | null>(null);

  useEffect(() => {
    if (!captureHotkey) {
      return;
    }

    const onKeyDown = (event: KeyboardEvent) => {
      event.preventDefault();
      if (event.code === 'Escape') {
        setCaptureHotkey(false);
        return;
      }
      const next = writeLocalSettings({ answerHotkey: event.code || 'Space' });
      setSettings(next);
      setCaptureHotkey(false);
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [captureHotkey]);

  useEffect(() => {
    if (!uid) {
      return;
    }
    return gameRepository.watchProfile(uid, (profile) => {
      if (!profile || profileModalOpen) {
        return;
      }
      setProfileNickname(profile.nickname);
      setProfileAvatarUrl(profile.avatarUrl);
      writeLocalProfile({ nickname: profile.nickname, avatarUrl: profile.avatarUrl });
    });
  }, [profileModalOpen, uid]);

  function onVolumeChange(value: number): void {
    const next = writeLocalSettings({ volume: value });
    setSettings(next);
  }

  function onSpectatorCleanChange(value: boolean): void {
    const next = writeLocalSettings({ spectatorCleanViewDefault: value });
    setSettings(next);
  }

  function openProfileModal(): void {
    const local = readLocalProfile();
    setProfileNickname(local.nickname);
    setProfileAvatarUrl(local.avatarUrl);
    setProfileError(null);
    setProfileModalOpen(true);
  }

  async function onSaveProfile(): Promise<void> {
    if (!uid) {
      setProfileError('User session is missing. Refresh and try again.');
      return;
    }
    if (!profileNickname.trim()) {
      setProfileError('Nickname is required.');
      return;
    }

    setProfileBusy(true);
    setProfileError(null);
    try {
      await gameRepository.upsertProfile(uid, profileNickname.trim(), profileAvatarUrl.trim());
      writeLocalProfile({
        nickname: profileNickname.trim(),
        avatarUrl: profileAvatarUrl.trim(),
      });
      setProfileModalOpen(false);
    } catch (reason) {
      setProfileError(reason instanceof Error ? reason.message : 'Failed to save profile');
    } finally {
      setProfileBusy(false);
    }
  }

  return (
    <>
      <section className="panel stack-16">
        <h2>{t('settings.title')}</h2>

        <div className="row gap-8 control-row">
          <span className="field-label">{t('settings.lang')}:</span>
          <select value={locale} onChange={(event) => setLocale(event.target.value as typeof locale)}>
            <option value="en">English</option>
            <option value="ru">Russian</option>
            <option value="uk">Ukrainian</option>
          </select>
        </div>

        <div className="row gap-8 control-row">
          <button className="primary-action" onClick={openProfileModal}>{t('settings.profile_edit')}</button>
        </div>

        <div className="stack-8 control-card">
          <span className="field-label">
            {t('settings.volume')}: {Math.round(settings.volume * 100)}%
          </span>
          <input
            className="volume-slider"
            type="range"
            min={0}
            max={1}
            step={0.05}
            value={settings.volume}
            onChange={(event) => onVolumeChange(Number.parseFloat(event.target.value) || 0)}
          />
        </div>

        <div className="stack-8 control-card">
          <span className="field-label">{t('settings.answer_hotkey')}</span>
          <div className="row gap-8 control-row">
            <span className="subtle-copy">
              {captureHotkey
                ? t('settings.answer_hotkey_press')
                : `${t('settings.answer_hotkey_current')}: ${hotkeyLabel(settings.answerHotkey)}`}
            </span>
            <button className="secondary-action" onClick={() => setCaptureHotkey((current) => !current)}>
              {captureHotkey ? t('settings.cancel') : t('settings.change')}
            </button>
          </div>
        </div>

        <label className="row gap-8 switch-row control-card">
          <input
            className="glass-switch"
            type="checkbox"
            checked={settings.spectatorCleanViewDefault}
            onChange={(event) => onSpectatorCleanChange(event.target.checked)}
          />
          <span>{t('settings.clean_default')}</span>
        </label>
      </section>

      {profileModalOpen ? (
        <div className="modal-backdrop" onClick={() => setProfileModalOpen(false)}>
          <section className="modal-card panel stack-16" onClick={(event) => event.stopPropagation()}>
            <h3>{t('settings.profile_modal_title')}</h3>
            <input
              placeholder={t('profile.nick')}
              value={profileNickname}
              maxLength={24}
              onChange={(event) => setProfileNickname(event.target.value)}
            />
            <input
              placeholder={t('profile.avatar')}
              value={profileAvatarUrl}
              onChange={(event) => setProfileAvatarUrl(event.target.value)}
            />
            <div className="row gap-8">
              <button className="primary-action" disabled={profileBusy} onClick={() => void onSaveProfile()}>
                {profileBusy ? 'Saving...' : t('profile.save')}
              </button>
              <button className="ghost-button" disabled={profileBusy} onClick={() => setProfileModalOpen(false)}>
                {t('settings.cancel')}
              </button>
            </div>
            {profileError ? <p className="error">{profileError}</p> : null}
          </section>
        </div>
      ) : null}
    </>
  );
}
