import { useEffect, useState } from 'react';

import { useI18n } from '../../../shared/i18n/i18nContext';
import { auth } from '../../../shared/firebase/client';
import { readLocalProfile, writeLocalProfile } from '../../../shared/profile/localProfile';
import { gameRepository } from '../../game/data/gameRepository';

export function ProfilePage() {
  const { t } = useI18n();
  const uid = auth.currentUser?.uid ?? '';
  const localProfile = readLocalProfile();

  const [nickname, setNickname] = useState(localProfile.nickname);
  const [avatarUrl, setAvatarUrl] = useState(localProfile.avatarUrl);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!uid) {
      return;
    }
    return gameRepository.watchProfile(uid, (profile) => {
      if (!profile) {
        return;
      }
      setNickname((current) => current || profile.nickname);
      setAvatarUrl((current) => current || profile.avatarUrl);
    });
  }, [uid]);

  async function onSave(): Promise<void> {
    if (!uid) {
      setError('User session is missing. Refresh and try again.');
      return;
    }
    if (!nickname.trim()) {
      setError('Nickname is required.');
      return;
    }

    setBusy(true);
    setError(null);
    setMessage(null);
    try {
      await gameRepository.upsertProfile(uid, nickname.trim(), avatarUrl.trim());
      writeLocalProfile({ nickname: nickname.trim(), avatarUrl: avatarUrl.trim() });
      setMessage(t('profile.saved'));
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Failed to save profile');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="panel stack-16 profile-panel">
      <h2>{t('profile.title')}</h2>
      <div className="profile-preview">
        {avatarUrl.trim() ? (
          <img src={avatarUrl.trim()} alt={nickname.trim() || 'avatar'} />
        ) : (
          <span>{(nickname.trim()[0] ?? '?').toUpperCase()}</span>
        )}
      </div>
      <input
        placeholder={t('profile.nick')}
        value={nickname}
        maxLength={24}
        onChange={(event) => setNickname(event.target.value)}
      />
      <input
        placeholder={t('profile.avatar')}
        value={avatarUrl}
        onChange={(event) => setAvatarUrl(event.target.value)}
      />
      <div className="row gap-8">
        <button className="primary-action" disabled={busy || !nickname.trim()} onClick={() => void onSave()}>
          {busy ? 'Saving...' : t('profile.save')}
        </button>
      </div>
      {message ? <p className="success-text">{message}</p> : null}
      {error ? <p className="error">{error}</p> : null}
    </section>
  );
}
