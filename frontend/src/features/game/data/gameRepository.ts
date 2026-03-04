import type { Unsubscribe } from 'firebase/firestore';

import type {
  FinalResult,
  GameEventModel,
  PackSummary,
  PlayerModel,
  PlayerRole,
  QuestionDraft,
  QuestionModel,
  RoomRules,
  RoomModel,
} from '../domain/models';
import { gameCommands } from './gameCommands';
import { mapGameEvent, mapPlayer, mapQuestion, mapRoom } from './firestoreMappers';
import { gameService } from './gameService';

type ProfileModel = {
  uid: string;
  nickname: string;
  avatarUrl: string;
};

export class GameRepository {
  watchProfile(uid: string, onData: (profile: ProfileModel | null) => void): Unsubscribe {
    return gameService.watchProfile(uid, (item) => {
      if (!item) {
        onData(null);
        return;
      }
      onData({
        uid,
        nickname: typeof item.data.nickname === 'string' ? item.data.nickname : '',
        avatarUrl: typeof item.data.avatarUrl === 'string' ? item.data.avatarUrl : '',
      });
    });
  }

  watchRooms(onData: (rooms: RoomModel[]) => void): Unsubscribe {
    return gameService.watchRooms((items) => {
      onData(items.map((item) => mapRoom(item.id, item.data)));
    });
  }

  watchRoom(roomId: string, onData: (room: RoomModel | null) => void): Unsubscribe {
    return gameService.watchRoom(roomId, (item) => {
      if (!item) {
        onData(null);
        return;
      }
      onData(mapRoom(item.id, item.data));
    });
  }

  watchPlayers(roomId: string, onData: (players: PlayerModel[]) => void): Unsubscribe {
    return gameService.watchPlayers(roomId, (items) => {
      onData(items.map((item) => mapPlayer(item.id, item.data)));
    });
  }

  watchQuestions(roomId: string, onData: (questions: QuestionModel[]) => void): Unsubscribe {
    return gameService.watchQuestions(roomId, (items) => {
      onData(items.map((item) => mapQuestion(item.id, item.data)));
    });
  }

  watchEvents(roomId: string, onData: (events: GameEventModel[]) => void): Unsubscribe {
    return gameService.watchEvents(roomId, (items) => {
      onData(items.map((item) => mapGameEvent(item.id, item.data)));
    });
  }

  upsertProfile(uid: string, nickname: string, avatarUrl = ''): Promise<Record<string, unknown>> {
    return gameService.callCommand({
      command: gameCommands.upsertProfile,
      uid,
      nickname,
      avatarUrl,
    });
  }

  async createRoom(roomName: string, password?: string): Promise<string> {
    const result = await gameService.callCommand({
      command: gameCommands.createRoom,
      roomName,
      ...(password ? { password } : {}),
    });
    const roomId = typeof result.roomId === 'string' ? result.roomId : '';
    if (!roomId) {
      throw new Error('Server did not return roomId');
    }
    return roomId;
  }

  joinRoom(roomId: string, role: PlayerRole = 'player', password?: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({
      command: gameCommands.joinRoom,
      roomId,
      role,
      ...(password ? { password } : {}),
    });
  }

  markDisconnected(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.markDisconnected, roomId });
  }

  updateRoomRules(roomId: string, rules: RoomRules): Promise<Record<string, unknown>> {
    return gameService.callCommand({
      command: gameCommands.updateRoomRules,
      roomId,
      falseStartEnabled: rules.falseStartEnabled,
      useAppeals: rules.useAppeals,
      timers: rules.timers,
    });
  }

  addQuestion(roomId: string, draft: QuestionDraft): Promise<Record<string, unknown>> {
    return gameService.callCommand({
      command: gameCommands.addQuestion,
      roomId,
      theme: draft.theme,
      text: draft.text,
      answer: draft.answer,
      cost: draft.cost,
      round: draft.round,
      type: draft.type,
      mediaUrl: draft.mediaUrl,
      mediaType: draft.mediaType,
      aliases: draft.aliases,
    });
  }

  addQuestionsBulk(roomId: string, drafts: QuestionDraft[]): Promise<Record<string, unknown>> {
    return gameService.callCommand({
      command: gameCommands.addQuestionsBulk,
      roomId,
      questions: drafts.map((draft) => ({
        theme: draft.theme,
        text: draft.text,
        answer: draft.answer,
        cost: draft.cost,
        round: draft.round,
        type: draft.type,
        mediaUrl: draft.mediaUrl,
        mediaType: draft.mediaType,
        aliases: draft.aliases,
      })),
    });
  }

  updateQuestion(roomId: string, questionId: string, draft: QuestionDraft): Promise<Record<string, unknown>> {
    return gameService.callCommand({
      command: gameCommands.updateQuestion,
      roomId,
      questionId,
      theme: draft.theme,
      text: draft.text,
      answer: draft.answer,
      cost: draft.cost,
      round: draft.round,
      type: draft.type,
      mediaUrl: draft.mediaUrl,
      mediaType: draft.mediaType,
      aliases: draft.aliases,
    });
  }

  deleteQuestion(roomId: string, questionId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.deleteQuestion, roomId, questionId });
  }

  async savePack(roomId: string, name: string): Promise<PackSummary> {
    const result = await gameService.callCommand({ command: gameCommands.savePack, roomId, name });
    return {
      id: typeof result.packId === 'string' ? result.packId : '',
      name,
      version: typeof result.version === 'number' ? result.version : 1,
      questionCount: 0,
    };
  }

  async listPacks(): Promise<PackSummary[]> {
    const result = await gameService.callCommand({ command: gameCommands.listPacks });
    const raw = Array.isArray(result.packs) ? result.packs : [];
    return raw.map((item) => {
      const map = (item ?? {}) as Record<string, unknown>;
      return {
        id: typeof map.id === 'string' ? map.id : '',
        name: typeof map.name === 'string' ? map.name : 'Pack',
        version: typeof map.version === 'number' ? map.version : 1,
        questionCount: typeof map.questionCount === 'number' ? map.questionCount : 0,
      };
    });
  }

  applyPack(roomId: string, packId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.applyPack, roomId, packId });
  }

  setPlayerRole(roomId: string, targetUid: string, role: PlayerRole): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.setPlayerRole, roomId, targetUid, role });
  }

  kickPlayer(roomId: string, targetUid: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.kickPlayer, roomId, targetUid });
  }

  banPlayer(roomId: string, targetUid: string, reason = ''): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.banPlayer, roomId, targetUid, reason });
  }

  unbanPlayer(roomId: string, targetUid: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.unbanPlayer, roomId, targetUid });
  }

  startGame(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.startGame, roomId });
  }

  advanceToRound2(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.advanceRound2, roomId });
  }

  startFinalRound(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.startFinalRound, roomId });
  }

  setFinalQuestion(roomId: string, theme: string, question: string, answer: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({
      command: gameCommands.setFinalQuestion,
      roomId,
      theme,
      question,
      answer,
    });
  }

  selectFinalThemeDeleter(roomId: string, targetUid: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({
      command: gameCommands.selectFinalThemeDeleter,
      roomId,
      targetUid,
    });
  }

  deleteFinalTheme(roomId: string, theme: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({
      command: gameCommands.deleteFinalTheme,
      roomId,
      theme,
    });
  }

  openFinalWagers(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.openFinalWagers, roomId });
  }

  openFinalAnswers(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.openFinalAnswers, roomId });
  }

  submitFinalWager(roomId: string, wager: number): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.submitFinalWager, roomId, wager });
  }

  submitFinalAnswer(roomId: string, answer: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.submitFinalAnswer, roomId, answer });
  }

  setFinalPlayerResult(roomId: string, targetUid: string, result: FinalResult): Promise<Record<string, unknown>> {
    return gameService.callCommand({
      command: gameCommands.setFinalPlayerResult,
      roomId,
      targetUid,
      result,
    });
  }

  revealFinal(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.revealFinal, roomId });
  }

  pickQuestion(roomId: string, questionId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.pickQuestion, roomId, questionId });
  }

  openBuzzing(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.openBuzzing, roomId });
  }

  selectCatTarget(roomId: string, targetUid: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.selectCatTarget, roomId, targetUid });
  }

  setWagerAndOpen(roomId: string, wager: number): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.setWagerAndOpen, roomId, wager });
  }

  pauseGame(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.pauseGame, roomId });
  }

  resumeGame(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.resumeGame, roomId });
  }

  buzz(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.buzz, roomId });
  }

  submitAnswer(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.submitAnswer, roomId });
  }

  submitNumericAnswer(roomId: string, value: number): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.submitNumericAnswer, roomId, value });
  }

  judgeAnswer(roomId: string, correct: boolean): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.judgeAnswer, roomId, correct });
  }

  submitAppeal(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.submitAppeal, roomId });
  }

  resolveAppeal(roomId: string, accepted: boolean): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.resolveAppeal, roomId, accepted });
  }

  handleTimerExpiration(roomId: string): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.handleTimerExpiration, roomId });
  }

  applyScore(roomId: string, targetUid: string, delta: number): Promise<Record<string, unknown>> {
    return gameService.callCommand({ command: gameCommands.applyScore, roomId, targetUid, delta });
  }
}

export const gameRepository = new GameRepository();
