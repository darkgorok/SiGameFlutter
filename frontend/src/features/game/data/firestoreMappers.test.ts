import { describe, expect, it } from 'vitest';

import { mapGameEvent, mapPlayer, mapRoom } from './firestoreMappers';

describe('mapRoom', () => {
  it('maps minimal room payload with defaults', () => {
    const room = mapRoom('room-1', {
      name: 'Room One',
      status: 'lobby',
      phase: 'lobby',
    });

    expect(room.id).toBe('room-1');
    expect(room.name).toBe('Room One');
    expect(room.passwordProtected).toBe(false);
    expect(room.rules.useAppeals).toBe(false);
    expect(room.appealActive).toBe(false);
    expect(room.currentRound).toBe(1);
    expect(room.activeQuestion).toBeNull();
  });

  it('maps password protection flags', () => {
    const room = mapRoom('room-2', {
      name: 'Room Two',
      passwordRequired: true,
      status: 'lobby',
      phase: 'lobby',
    });

    expect(room.passwordProtected).toBe(true);
  });
});

describe('mapPlayer', () => {
  it('maps player stats with defaults', () => {
    const player = mapPlayer('uid-1', {
      nickname: 'Neo',
      score: 300,
      connected: true,
    });

    expect(player.uid).toBe('uid-1');
    expect(player.nickname).toBe('Neo');
    expect(player.correctAnswers).toBe(0);
    expect(player.wrongAnswers).toBe(0);
    expect(player.buzzCount).toBe(0);
  });
});

describe('mapGameEvent', () => {
  it('maps event payload', () => {
    const event = mapGameEvent('event-1', {
      type: 'join',
      message: 'Player joined room',
      actorUid: 'uid-1',
      createdAt: 1700000000000,
    });

    expect(event.id).toBe('event-1');
    expect(event.type).toBe('join');
    expect(event.message).toBe('Player joined room');
    expect(event.actorUid).toBe('uid-1');
    expect(event.createdAt?.getTime()).toBe(1700000000000);
  });
});
