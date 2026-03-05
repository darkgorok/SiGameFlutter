import { useEffect, useMemo, useState } from 'react';
import { useI18n } from '../../../shared/i18n/i18nContext';
import { useNavigate } from 'react-router-dom';

import { gameRepository } from '../../game/data/gameRepository';
import type { PlayerRole, RoomModel } from '../../game/domain/models';

export function RoomsPage() {
  const { t } = useI18n();
  const [rooms, setRooms] = useState<RoomModel[]>([]);
  const [newRoomName, setNewRoomName] = useState('');
  const [passwordInput, setPasswordInput] = useState('');
  const [pendingJoin, setPendingJoin] = useState<{ room: RoomModel; role: PlayerRole } | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();

  useEffect(() => {
    return gameRepository.watchRooms(setRooms);
  }, []);

  const sortedRooms = useMemo(() => {
    return [...rooms].sort((a, b) => a.name.localeCompare(b.name));
  }, [rooms]);

  async function onCreateRoom(): Promise<void> {
    if (!newRoomName.trim()) return;
    setBusy(true);
    setError(null);
    try {
      const roomId = await gameRepository.createRoom(newRoomName.trim());
      await gameRepository.joinRoom(roomId, 'host');
      navigate(`/room/${roomId}`);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Failed to create room');
    } finally {
      setBusy(false);
    }
  }

  async function onJoinRoom(room: RoomModel, role: PlayerRole, password?: string): Promise<boolean> {
    setBusy(true);
    setError(null);
    try {
      await gameRepository.joinRoom(room.id, role, password);
      navigate(`/room/${room.id}`);
      return true;
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Failed to join room');
      return false;
    } finally {
      setBusy(false);
    }
  }

  function onJoinClick(room: RoomModel, role: PlayerRole): void {
    if (!room.passwordProtected) {
      void onJoinRoom(room, role);
      return;
    }
    setPasswordInput('');
    setPendingJoin({ room, role });
  }

  function closePasswordDialog(): void {
    if (busy) {
      return;
    }
    setPendingJoin(null);
    setPasswordInput('');
  }

  async function submitPasswordJoin(): Promise<void> {
    if (!pendingJoin) {
      return;
    }
    const password = passwordInput.trim();
    if (!password) {
      setError(t('rooms.password_prompt'));
      return;
    }
    const joined = await onJoinRoom(pendingJoin.room, pendingJoin.role, password);
    if (joined) {
      setPendingJoin(null);
      setPasswordInput('');
    }
  }

  const pendingJoinLabel =
    pendingJoin?.role === 'spectator' ? t('rooms.join_spectator') : t('rooms.join_player');

  return (
    <section className="panel stack-16">
      <h2>{t('rooms.title')}</h2>
      <div className="row gap-8">
        <input
          placeholder={t('rooms.new_name')}
          value={newRoomName}
          onChange={(event) => setNewRoomName(event.target.value)}
        />
        <button className="primary-action" disabled={busy || !newRoomName.trim()} onClick={() => void onCreateRoom()}>
          {t('rooms.create')}
        </button>
      </div>
      {error ? <p className="error">{error}</p> : null}
      <div className="stack-8">
        {sortedRooms.length === 0 ? <p>{t('rooms.empty')}</p> : null}
        {sortedRooms.map((room) => (
          <article className="room-card" key={room.id}>
            <div>
              <strong>
                {room.name}
                {room.passwordProtected ? ` (${t('rooms.protected')})` : ''}
              </strong>
              <p className="room-meta">
                <span className="status-chip">{room.status}</span>
                <span className="phase-chip">{room.phase}</span>
              </p>
            </div>
            <div className="row gap-8">
              <button className="primary-action" disabled={busy} onClick={() => onJoinClick(room, 'player')}>
                {t('rooms.join_player')}
              </button>
              <button disabled={busy} onClick={() => onJoinClick(room, 'spectator')}>
                {t('rooms.join_spectator')}
              </button>
            </div>
          </article>
        ))}
      </div>
      {pendingJoin ? (
        <div className="modal-backdrop" role="presentation" onClick={closePasswordDialog}>
          <article
            className="panel modal-card stack-16"
            role="dialog"
            aria-modal="true"
            aria-label={t('rooms.password_prompt')}
            onClick={(event) => event.stopPropagation()}
          >
            <h3 className="dialog-title">{t('rooms.password_prompt')}</h3>
            <p>{pendingJoin.room.name}</p>
            <input
              autoFocus
              type="password"
              placeholder={t('rooms.password_prompt')}
              value={passwordInput}
              onChange={(event) => setPasswordInput(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === 'Enter') {
                  event.preventDefault();
                  void submitPasswordJoin();
                } else if (event.key === 'Escape') {
                  event.preventDefault();
                  closePasswordDialog();
                }
              }}
            />
            <div className="row gap-8 dialog-actions">
              <button disabled={busy} onClick={() => void submitPasswordJoin()}>
                {pendingJoinLabel}
              </button>
              <button className="ghost-button" disabled={busy} onClick={closePasswordDialog}>
                {t('settings.back')}
              </button>
            </div>
          </article>
        </div>
      ) : null}
    </section>
  );
}
