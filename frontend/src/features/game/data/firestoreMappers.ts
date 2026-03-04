import { Timestamp, type DocumentData } from 'firebase/firestore';

import type {
  ActiveQuestion,
  FinalResult,
  GamePhase,
  GameStatus,
  PlayerModel,
  PlayerRole,
  QuestionMediaType,
  QuestionModel,
  QuestionType,
  RoomModel,
  GameEventModel,
} from '../domain/models';

function readString(value: unknown, fallback = ''): string {
  return typeof value === 'string' ? value : fallback;
}

function readNumber(value: unknown, fallback = 0): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function readNullableNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function readStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter((item): item is string => typeof item === 'string');
}

function readStringNumberMap(value: unknown): Record<string, number> {
  if (!value || typeof value !== 'object') {
    return {};
  }
  const raw = value as Record<string, unknown>;
  const out: Record<string, number> = {};
  for (const [key, item] of Object.entries(raw)) {
    if (typeof item === 'number' && Number.isFinite(item)) {
      out[key] = item;
    }
  }
  return out;
}

function readQuestionType(value: unknown): QuestionType {
  const raw = readString(value, 'normal').trim().toLowerCase().replace(/[\s-]+/g, '_');
  if (raw === 'cat' || raw === 'bagcat' || raw === 'cat_in_bag') return 'cat_in_bag';
  if (raw === 'auction' || raw === 'wager' || raw === 'stake' || raw === 'stake_all' || raw === 'stakeall') return 'wager';
  if (raw === 'closest_number') return 'closest_number';
  return 'normal';
}

function readQuestionMediaType(value: unknown): QuestionMediaType {
  const raw = readString(value, 'none').trim().toLowerCase();
  if (raw === 'image' || raw === 'audio' || raw === 'video') {
    return raw;
  }
  return 'none';
}

function mapActiveQuestion(input: unknown): ActiveQuestion | null {
  if (!input || typeof input !== 'object') {
    return null;
  }
  const data = input as Record<string, unknown>;
  return {
    id: readString(data.id),
    theme: readString(data.theme),
    text: readString(data.text),
    answer: readString(data.answer),
    cost: readNumber(data.cost),
    type: readQuestionType(data.type),
  };
}

export function mapRoom(id: string, data: DocumentData): RoomModel {
  const hasPassword =
    Boolean(data.passwordProtected) || Boolean(data.hasPassword) || Boolean(data.passwordRequired);
  return {
    id,
    name: readString(data.name, id),
    hostUid: readString(data.hostUid),
    passwordProtected: hasPassword,
    status: readString(data.status, 'lobby') as GameStatus,
    phase: readString(data.phase, 'lobby') as GamePhase,
    currentRound: readNumber(data.currentRound, 1),
    currentQuestionId: readString(data.currentQuestionId) || null,
    currentAttemptUid: readString(data.currentAttemptUid) || null,
    buzzQueue: readStringArray(data.buzzQueue),
    pausedByUid: readString(data.pausedByUid) || null,
    chooserUid: readString(data.chooserUid) || null,
    targetedUid: readString(data.targetedUid) || null,
    wagerValue: readNullableNumber(data.wagerValue),
    timerDeadlineAtMs: readNullableNumber(data.timerDeadlineAtMs),
    timerRemainingMs: readNullableNumber(data.timerRemainingMs),
    activeQuestion: mapActiveQuestion(data.activeQuestion),
    finalTheme: readString(data.finalTheme) || null,
    finalQuestion: readString(data.finalQuestion) || null,
    finalAnswer: readString(data.finalAnswer) || null,
    finalThemePool: readStringArray(data.finalThemePool),
    finalThemeDeleteCandidates: readStringArray(data.finalThemeDeleteCandidates),
    finalThemeDeleteNeedsSelection: Boolean(data.finalThemeDeleteNeedsSelection),
    finalThemeDeleteCurrentUid: readString(data.finalThemeDeleteCurrentUid) || null,
    finalEligibleUids: readStringArray(data.finalEligibleUids),
    finalAnswerOrder: readStringArray(data.finalAnswerOrder),
    finalAnswerCurrentUid: readString(data.finalAnswerCurrentUid) || null,
    finalRevealOrder: readStringArray(data.finalRevealOrder),
    finalRevealCurrentUid: readString(data.finalRevealCurrentUid) || null,
    rules: {
      falseStartEnabled: Boolean(data.rules?.falseStartEnabled),
      useAppeals: Boolean(data.rules?.useAppeals),
      timers: readStringNumberMap(data.rules?.timers),
    },
    appealActive: Boolean(data.appealActive),
    appealRequestedByUid: readString(data.appealRequestedByUid) || null,
    appealForUid: readString(data.appealForUid) || null,
  };
}

export function mapPlayer(id: string, data: DocumentData): PlayerModel {
  return {
    uid: readString(data.uid, id),
    nickname: readString(data.nickname, 'Player'),
    role: readString(data.role, 'player') as PlayerRole,
    score: readNumber(data.score),
    connected: Boolean(data.connected),
    correctAnswers: readNumber(data.correctAnswers),
    wrongAnswers: readNumber(data.wrongAnswers),
    buzzCount: readNumber(data.buzzCount),
    finalResult: readString(data.finalResult, 'pending') as FinalResult,
    finalWager: readNumber(data.finalWager),
    finalWagerSubmitted: Boolean(data.finalWagerSubmitted),
    finalAnswerSubmitted: Boolean(data.finalAnswerSubmitted),
    finalAnswerText: readString(data.finalAnswerText),
    finalRevealed: Boolean(data.finalRevealed),
  };
}

export function mapQuestion(id: string, data: DocumentData): QuestionModel {
  return {
    id,
    theme: readString(data.theme),
    text: readString(data.text),
    answer: readString(data.answer),
    cost: readNumber(data.cost),
    round: readNumber(data.round, 1),
    type: readQuestionType(data.type),
    mediaUrl: readString(data.mediaUrl),
    mediaType: readQuestionMediaType(data.mediaType),
    aliases: readStringArray(data.aliases),
    used: Boolean(data.used),
  };
}

function readDate(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (value instanceof Timestamp) return value.toDate();
  if (typeof value === 'number' && Number.isFinite(value)) {
    return new Date(value);
  }
  if (typeof value === 'string') {
    const time = Date.parse(value);
    if (!Number.isNaN(time)) {
      return new Date(time);
    }
  }
  return null;
}

export function mapGameEvent(id: string, data: DocumentData): GameEventModel {
  return {
    id,
    type: readString(data.type, 'system'),
    message: readString(data.message),
    actorUid: readString(data.actorUid),
    createdAt: readDate(data.createdAt),
  };
}
