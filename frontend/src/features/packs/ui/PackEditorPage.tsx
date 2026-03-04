import { useEffect, useState } from 'react';
import { useI18n } from '../../../shared/i18n/i18nContext';
import { Link } from 'react-router-dom';

import { gameRepository } from '../../game/data/gameRepository';
import type { PackSummary } from '../../game/domain/models';

export function PackEditorPage() {
  const { t } = useI18n();
  const [roomId, setRoomId] = useState('');
  const [packName, setPackName] = useState('My Pack');
  const [packs, setPacks] = useState<PackSummary[]>([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function loadPacks(): Promise<void> {
    try {
      const list = await gameRepository.listPacks();
      setPacks(list);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Failed to load packs');
    }
  }

  useEffect(() => {
    void loadPacks();
  }, []);

  async function run(action: () => Promise<unknown>, successMessage: string): Promise<void> {
    setBusy(true);
    setError(null);
    setMessage(null);
    try {
      await action();
      setMessage(successMessage);
      await loadPacks();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Action failed');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="stack-16">
      <article className="panel stack-8">
        <h2>{t('packs.title')}</h2>
        <p>{t('packs.subtitle')}</p>
        <div className="row gap-8">
          <input
            placeholder={t('packs.room_id')}
            value={roomId}
            onChange={(event) => setRoomId(event.target.value)}
          />
          {roomId.trim() ? (
            <Link className="button-link" to={`/room/${roomId.trim()}/editor`}>
              {t('packs.open_editor')}
            </Link>
          ) : null}
        </div>
        <div className="row gap-8">
          <input
            placeholder={t('packs.name')}
            value={packName}
            onChange={(event) => setPackName(event.target.value)}
          />
          <button
            disabled={busy || !roomId.trim() || !packName.trim()}
            onClick={() =>
              void run(
                () => gameRepository.savePack(roomId.trim(), packName.trim()),
                'Pack saved from room',
              )
            }
          >
            {t('packs.save')}
          </button>
          <button disabled={busy} onClick={() => void loadPacks()}>
            {t('packs.refresh')}
          </button>
        </div>
        {message ? <p>{message}</p> : null}
        {error ? <p className="error">{error}</p> : null}
      </article>

      <article className="panel stack-8">
        <h3>{t('packs.available')}</h3>
        {packs.length === 0 ? <p>{t('packs.empty')}</p> : null}
        {packs.map((pack) => (
          <div key={pack.id} className="room-card">
            <div>
              <strong>{pack.name}</strong>
              <p>
                version {pack.version} / questions {pack.questionCount}
              </p>
              <p>{pack.id}</p>
            </div>
            <button
              disabled={busy || !roomId.trim()}
              onClick={() =>
                void run(() => gameRepository.applyPack(roomId.trim(), pack.id), `Pack ${pack.name} applied`)
              }
            >
              {t('packs.apply')}
            </button>
          </div>
        ))}
      </article>
    </section>
  );
}
