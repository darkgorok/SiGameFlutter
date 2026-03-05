import { useState } from 'react';
import { useI18n } from '../../../shared/i18n/i18nContext';

import { auth } from '../../../shared/firebase/client';
import { writeLocalProfile } from '../../../shared/profile/localProfile';
import { gameRepository } from '../../game/data/gameRepository';

type Props = {
  onSaved: () => void;
};

export function InitialProfileSetupPage({ onSaved }: Props) {
  const { t } = useI18n();
  const [nickname, setNickname] = useState('');
  const [avatarUrl, setAvatarUrl] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(): Promise<void> {
    const uid = auth.currentUser?.uid;
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
    try {
      await gameRepository.upsertProfile(uid, nickname.trim(), avatarUrl.trim());
      writeLocalProfile({ nickname: nickname.trim(), avatarUrl: avatarUrl.trim() });
      onSaved();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Failed to save profile');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="center">
      <article className="panel stack-16 profile-setup-card profile-panel">
        <h2>{t('profile.setup_title')}</h2>
        <p>{t('profile.setup_subtitle')}</p>
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
        <button className="primary-action" disabled={busy || !nickname.trim()} onClick={() => void onSubmit()}>
          {busy ? 'Saving...' : t('profile.continue')}
        </button>
        {error ? <p className="error">{error}</p> : null}
      </article>
    </section>
  );
}
