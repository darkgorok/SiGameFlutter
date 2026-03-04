import { describe, expect, it } from 'vitest';

import { getRoomUiPermissions } from './gameUiPermissions';
import type { RoomModel } from '../domain/models';

function makeRoom(overrides: Partial<RoomModel> = {}): RoomModel {
  return {
    id: 'room-1',
    name: 'Room',
    hostUid: 'host',
    passwordProtected: false,
    status: 'in_game',
    phase: 'board_select',
    currentRound: 1,
    currentQuestionId: null,
    currentAttemptUid: null,
    buzzQueue: [],
    pausedByUid: null,
    chooserUid: 'player-1',
    timerDeadlineAtMs: null,
    timerRemainingMs: null,
    activeQuestion: null,
    targetedUid: null,
    wagerValue: null,
    finalTheme: null,
    finalQuestion: null,
    finalAnswer: null,
    finalThemePool: [],
    finalThemeDeleteCandidates: [],
    finalThemeDeleteNeedsSelection: false,
    finalThemeDeleteCurrentUid: null,
    finalEligibleUids: [],
    finalAnswerOrder: [],
    finalAnswerCurrentUid: null,
    finalRevealOrder: [],
    finalRevealCurrentUid: null,
    rules: {
      falseStartEnabled: false,
      useAppeals: false,
      timers: {},
    },
    appealActive: false,
    appealRequestedByUid: null,
    appealForUid: null,
    ...overrides,
  };
}

describe('getRoomUiPermissions', () => {
  it('allows chooser or host to pick question on board_select', () => {
    const room = makeRoom();
    const chooser = getRoomUiPermissions({ room, uid: 'player-1', myRole: 'player', isHost: false });
    const host = getRoomUiPermissions({ room, uid: 'host', myRole: 'host', isHost: true });

    expect(chooser.canPickQuestion).toBe(true);
    expect(host.canPickQuestion).toBe(true);
  });

  it('blocks buzz when already attempted or queued', () => {
    const room = makeRoom({
      phase: 'answering',
      currentAttemptUid: 'player-2',
      buzzQueue: ['player-1'],
      activeQuestion: { id: 'q', theme: 't', text: 'x', answer: 'a', cost: 100, type: 'normal' },
    });
    const perms = getRoomUiPermissions({ room, uid: 'player-1', myRole: 'player', isHost: false });
    expect(perms.canBuzz).toBe(false);
  });

  it('allows start only in lobby for host', () => {
    const lobbyRoom = makeRoom({ status: 'lobby', phase: 'lobby' });
    const inGameRoom = makeRoom({ status: 'in_game', phase: 'board_select' });

    expect(getRoomUiPermissions({ room: lobbyRoom, uid: 'host', myRole: 'host', isHost: true }).canStartGame).toBe(true);
    expect(getRoomUiPermissions({ room: inGameRoom, uid: 'host', myRole: 'host', isHost: true }).canStartGame).toBe(false);
  });
});
