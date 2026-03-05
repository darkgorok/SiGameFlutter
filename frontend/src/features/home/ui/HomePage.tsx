
import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useI18n } from '../../../shared/i18n/i18nContext';
import { gameRepository } from '../../game/data/gameRepository';
import type { LocalPackDocument } from '../../packs/data/localPack';
import { parseLocalPackJson } from '../../packs/data/localPack';

export function HomePage() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [roomName, setRoomName] = useState('');
  const [password, setPassword] = useState('');
  const [selectedPack, setSelectedPack] = useState<LocalPackDocument | null>(null);
  const [packFileName, setPackFileName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function openCreateModal(): void {
    setCreateModalOpen(true);
    setError(null);
  }

  function closeCreateModal(): void {
    if (busy) {
      return;
    }
    setCreateModalOpen(false);
  }

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
      setCreateModalOpen(false);
      navigate(`/room/${roomId}`);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Failed to create room');
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <section className="home-only-menu">
        <button className="button-link primary-action" onClick={openCreateModal}>
          {t('home.create_room')}
        </button>
        <Link className="button-link" to="/rooms">
          {t('home.find_room')}
        </Link>
        <Link className="button-link" to="/settings">
          {t('home.settings')}
        </Link>
        <Link className="button-link" to="/pack-editor">
          {t('home.pack_editor')}
        </Link>
      </section>

      {createModalOpen ? (
        <div className="modal-backdrop" onClick={closeCreateModal}>
          <section className="modal-card panel stack-16" onClick={(event) => event.stopPropagation()}>
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
                className="file-picker"
                type="file"
                accept="application/json,.json"
                onChange={(event) => {
                  const file = event.target.files?.[0] ?? null;
                  void onPackSelected(file);
                }}
              />
              <p className="subtle-copy">
                {selectedPack
                  ? t('home.pack_loaded').replace('{count}', String(selectedPack.questions.length))
                  : t('home.pack_required')}
                {packFileName ? ` (${packFileName})` : ''}
              </p>
            </div>
            <div className="row gap-8 dialog-actions">
              <button className="primary-action" disabled={busy} onClick={() => void onCreateRoom()}>
                {t('home.create_room')}
              </button>
              <button className="ghost-button" disabled={busy} onClick={closeCreateModal}>
                {t('settings.cancel')}
              </button>
            </div>
            {error ? <p className="error">{error}</p> : null}
          </section>
        </div>
      ) : null}
    </>
  );
}
