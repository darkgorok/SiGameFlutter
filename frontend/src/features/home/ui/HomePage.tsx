
import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';

import { gameRepository } from '../../game/data/gameRepository';
import type { LocalPackDocument } from '../../packs/data/localPack';
import { parseLocalPackJson } from '../../packs/data/localPack';
import { useI18n } from '../../../shared/i18n/i18nContext';

const defaultRoomName = 'New game';

export function HomePage() {
  const { t } = useI18n();
  const navigate = useNavigate();

  const [roomName, setRoomName] = useState(defaultRoomName);
  const [password, setPassword] = useState('');
  const [selectedPack, setSelectedPack] = useState<LocalPackDocument | null>(null);
  const [packFileName, setPackFileName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onPackSelected(file: File | null): Promise<void> {
    if (!file) {
      setSelectedPack(null);
      setPackFileName('');
      return;
    }

    setError(null);
    try {
      const text = await file.text();
      const parsed = parseLocalPackJson(text);
      if (parsed.questions.length === 0) {
        throw new Error(t('home.pack_no_questions'));
      }
      setSelectedPack(parsed);
      setPackFileName(file.name);
    } catch {
      setSelectedPack(null);
      setPackFileName('');
      setError(t('home.pack_invalid'));
    }
  }

  async function onCreateRoom(): Promise<void> {
    const normalizedRoomName = roomName.trim();
    const normalizedPassword = password.trim();
    if (!normalizedRoomName) {
      setError(t('home.room_name_required'));
      return;
    }
    if (!selectedPack) {
      setError(t('home.pack_required'));
      return;
    }

    setBusy(true);
    setError(null);

    try {
      const roomId = await gameRepository.createRoom(
        normalizedRoomName,
        normalizedPassword || undefined,
      );
      await gameRepository.joinRoom(roomId, 'host');
      await gameRepository.addQuestionsBulk(roomId, selectedPack.questions);
      navigate(`/room/${roomId}/editor`);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Failed to create room');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="stack-16">
      <article className="panel stack-16">
        <h2>{t('home.title')}</h2>
        <p>{t('home.subtitle')}</p>

        <div className="row gap-8">
          <Link className="button-link" to="/rooms">
            {t('home.find_room')}
          </Link>
          <Link className="button-link" to="/settings">
            {t('home.settings')}
          </Link>
          <Link className="button-link" to="/pack-editor">
            {t('home.pack_editor')}
          </Link>
        </div>
      </article>

      <article className="panel stack-8">
        <h3>{t('home.create_room_title')}</h3>
        <input
          placeholder={t('home.room_name')}
          value={roomName}
          onChange={(event) => setRoomName(event.target.value)}
        />
        <input
          placeholder={t('home.room_password')}
          value={password}
          onChange={(event) => setPassword(event.target.value)}
        />
        <div className="stack-8">
          <input
            type="file"
            accept="application/json,.json"
            onChange={(event) => {
              const file = event.target.files?.[0] ?? null;
              void onPackSelected(file);
            }}
          />
          <p>
            {selectedPack
              ? t('home.pack_loaded').replace('{count}', String(selectedPack.questions.length))
              : t('home.pack_required')}
            {packFileName ? ` (${packFileName})` : ''}
          </p>
        </div>
        <button disabled={busy} onClick={() => void onCreateRoom()}>
          {t('home.create_room')}
        </button>
        {error ? <p className="error">{error}</p> : null}
      </article>
    </section>
  );
}
