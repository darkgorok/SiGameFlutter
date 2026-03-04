import type { PlayerModel, RoomModel } from '../domain/models';

export type RoomUiPermissions = {
  isPaused: boolean;
  isFinalState: boolean;
  isCompletedState: boolean;
  canStartGame: boolean;
  canAdvanceRound2: boolean;
  canStartFinalRound: boolean;
  canPause: boolean;
  canResume: boolean;
  canPickQuestion: boolean;
  canBuzz: boolean;
  canOpenBuzzing: boolean;
};

export function getRoomUiPermissions(params: {
  room: RoomModel;
  uid: string;
  myRole: PlayerModel['role'];
  isHost: boolean;
}): RoomUiPermissions {
  const { room, uid, myRole, isHost } = params;
  const isPaused = room.status === 'paused';
  const isLobby = room.status === 'lobby' && room.phase === 'lobby';
  const isFinalState =
    room.status === 'final_round' ||
    room.phase === 'final_setup' ||
    room.phase === 'final_wagering' ||
    room.phase === 'final_answering' ||
    room.phase === 'final_reveal';
  const isCompletedState = room.status === 'completed' || room.phase === 'game_over';
  const canPauseBase = myRole !== 'spectator' || isHost;

  const canPickQuestion =
    !isPaused &&
    room.phase === 'board_select' &&
    (room.chooserUid === uid || room.hostUid === uid);

  const canBuzz =
    room.phase === 'answering' &&
    !isPaused &&
    room.activeQuestion?.type !== 'closest_number' &&
    !room.currentAttemptUid &&
    !room.buzzQueue.includes(uid) &&
    (!room.targetedUid || room.targetedUid === uid);

  return {
    isPaused,
    isFinalState,
    isCompletedState,
    canStartGame: isHost && isLobby,
    canAdvanceRound2: isHost && !isPaused && !isFinalState && !isCompletedState && room.currentRound < 2,
    canStartFinalRound: isHost && !isPaused && !isFinalState && !isCompletedState,
    canPause: canPauseBase && !isCompletedState && !isPaused,
    canResume: (room.pausedByUid === uid || isHost) && isPaused,
    canPickQuestion,
    canBuzz,
    canOpenBuzzing: isHost && room.phase === 'question_reveal' && !isPaused,
  };
}
