import { useEffect, useMemo, useState } from 'react';
import { useI18n } from '../../../shared/i18n/i18nContext';
import { useNavigate } from 'react-router-dom';

import { gameRepository } from '../../game/data/gameRepository';
import type { PlayerRole, RoomModel } from '../../game/domain/models';

export function RoomsPage() {
  const { t } = useI18n();
  const [rooms, setRooms] = useState<RoomModel[]>([]);
  const [newRoomName, setNewRoomName] = useState('');
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

  async function onJoinRoom(room: RoomModel, role: PlayerRole): Promise<void> {
    setBusy(true);
    setError(null);
    try {
      let password: string | undefined;
      if (room.passwordProtected) {
        const entered = window.prompt(`${t('rooms.password_prompt')} ${room.name}`)?.trim();
        if (!entered) {
          setBusy(false);
          return;
        }
        password = entered;
      }
      await gameRepository.joinRoom(room.id, role, password);
      navigate(`/room/${room.id}`);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Failed to join room');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="panel stack-16">
      <h2>{t('rooms.title')}</h2>
      <div className="row gap-8">
        <input
          placeholder={t('rooms.new_name')}
          value={newRoomName}
          onChange={(event) => setNewRoomName(event.target.value)}
        />
        <button disabled={busy || !newRoomName.trim()} onClick={() => void onCreateRoom()}>
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
              <p>
                {room.status} / {room.phase}
              </p>
            </div>
            <div className="row gap-8">
              <button disabled={busy} onClick={() => void onJoinRoom(room, 'player')}>
                {t('rooms.join_player')}
              </button>
              <button disabled={busy} onClick={() => void onJoinRoom(room, 'spectator')}>
                {t('rooms.join_spectator')}
              </button>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}
