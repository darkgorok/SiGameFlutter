import {
  collection,
  doc,
  limit,
  onSnapshot,
  orderBy,
  query,
  type Unsubscribe,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';

import { db, functions } from '../../../shared/firebase/client';
import type { GameCommand } from './gameCommands';

type CommandPayload = {
  command: GameCommand;
  roomId?: string;
  [key: string]: unknown;
};

type CommandResult = Record<string, unknown>;

export class GameService {
  watchProfile(
    uid: string,
    onData: (profile: { id: string; data: Record<string, unknown> } | null) => void,
  ): Unsubscribe {
    return onSnapshot(doc(db, 'profiles', uid), (snapshot) => {
      if (!snapshot.exists()) {
        onData(null);
        return;
      }
      onData({ id: snapshot.id, data: snapshot.data() });
    });
  }

  watchRooms(onData: (rooms: Array<{ id: string; data: Record<string, unknown> }>) => void): Unsubscribe {
    const roomsQuery = query(collection(db, 'rooms'), orderBy('createdAt', 'desc'), limit(100));
    return onSnapshot(roomsQuery, (snapshot) => {
      onData(snapshot.docs.map((item) => ({ id: item.id, data: item.data() })));
    });
  }

  watchRoom(roomId: string, onData: (room: { id: string; data: Record<string, unknown> } | null) => void): Unsubscribe {
    return onSnapshot(doc(db, 'rooms', roomId), (snapshot) => {
      if (!snapshot.exists()) {
        onData(null);
        return;
      }
      onData({ id: snapshot.id, data: snapshot.data() });
    });
  }

  watchPlayers(roomId: string, onData: (players: Array<{ id: string; data: Record<string, unknown> }>) => void): Unsubscribe {
    const playersQuery = query(collection(db, 'rooms', roomId, 'players'), orderBy('score', 'desc'));
    return onSnapshot(playersQuery, (snapshot) => {
      onData(snapshot.docs.map((item) => ({ id: item.id, data: item.data() })));
    });
  }

  watchQuestions(roomId: string, onData: (questions: Array<{ id: string; data: Record<string, unknown> }>) => void): Unsubscribe {
    const questionsQuery = query(
      collection(db, 'rooms', roomId, 'questions'),
      orderBy('round'),
      orderBy('theme'),
      orderBy('cost'),
    );
    return onSnapshot(questionsQuery, (snapshot) => {
      onData(snapshot.docs.map((item) => ({ id: item.id, data: item.data() })));
    });
  }

  watchEvents(roomId: string, onData: (events: Array<{ id: string; data: Record<string, unknown> }>) => void): Unsubscribe {
    const eventsQuery = query(
      collection(db, 'rooms', roomId, 'events'),
      orderBy('createdAt', 'desc'),
      limit(200),
    );
    return onSnapshot(eventsQuery, (snapshot) => {
      onData(snapshot.docs.map((item) => ({ id: item.id, data: item.data() })));
    });
  }

  async callCommand(payload: CommandPayload): Promise<CommandResult> {
    const call = httpsCallable<CommandPayload, CommandResult>(functions, 'gameCommand');
    const { command, roomId, ...data } = payload;
    const result = await call({
      command,
      ...(roomId ? { roomId } : {}),
      data,
    });
    return result.data;
  }
}

export const gameService = new GameService();
