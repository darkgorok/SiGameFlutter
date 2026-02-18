import 'package:cloud_firestore/cloud_firestore.dart';

import '../game_models.dart';
import '../game_service.dart';
import 'game_dtos.dart';
import 'game_mappers.dart';
import 'game_repository.dart';

class GameRepositoryImpl implements GameRepository {
  GameRepositoryImpl(this._service);

  final GameService _service;

  @override
  Stream<List<RoomModel>> watchRooms() {
    return _service.watchRooms().map(
      (snapshot) => snapshot.docs
          .map((doc) => RoomDto.fromSnapshot(doc).toDomain())
          .toList(),
    );
  }

  @override
  Stream<List<RoomModel>> watchRoomsLimited({required int limit}) {
    return _service
        .watchRoomsLimited(limit: limit)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RoomDto.fromSnapshot(doc).toDomain())
              .toList(),
        );
  }

  @override
  Future<RoomsPageModel> fetchRoomsPage({
    required int limit,
    int? startAfterCreatedAtMs,
  }) async {
    final snapshot = await _service.fetchRoomsPage(
      limit: limit,
      startAfterCreatedAtMs: startAfterCreatedAtMs,
    );
    final docs = snapshot.docs;
    final hasMore = docs.length > limit;
    final selected = hasMore ? docs.take(limit).toList() : docs;
    final rooms = selected
        .map((doc) => RoomDto.fromSnapshot(doc).toDomain())
        .toList();
    final lastData = selected.isEmpty ? null : selected.last.data();
    final lastCreatedAt = lastData?['createdAt'];
    final nextCursorCreatedAtMs = hasMore && lastCreatedAt is Timestamp
        ? lastCreatedAt.millisecondsSinceEpoch
        : null;
    return RoomsPageModel(
      rooms: rooms,
      nextCursorCreatedAtMs: nextCursorCreatedAtMs,
      hasMore: hasMore && nextCursorCreatedAtMs != null,
    );
  }

  @override
  Stream<RoomModel?> watchRoom(String roomId) {
    return _service.watchRoom(roomId).map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return RoomDto.fromSnapshot(snapshot).toDomain();
    });
  }

  @override
  Stream<List<PlayerModel>> watchPlayers(String roomId) {
    return _service
        .watchPlayers(roomId)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PlayerDto.fromSnapshot(doc).toDomain())
              .toList(),
        );
  }

  @override
  Stream<List<QuestionModel>> watchQuestions(String roomId) {
    return _service
        .watchQuestions(roomId)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => QuestionDto.fromSnapshot(doc).toDomain())
              .toList(),
        );
  }

  @override
  Stream<List<GameEventModel>> watchEvents(String roomId) {
    return _service
        .watchEvents(roomId)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GameEventDto.fromSnapshot(doc).toDomain())
              .toList(),
        );
  }

  @override
  Future<void> upsertProfile({
    required String uid,
    required String nickname,
    required String avatarUrl,
  }) => _service.upsertProfile(
    uid: uid,
    nickname: nickname,
    avatarUrl: avatarUrl,
  );

  @override
  Future<String> createRoom({required String roomName, String? password}) =>
      _service.createRoom(roomName: roomName, password: password);

  @override
  Future<void> joinRoom(
    String roomId, {
    PlayerRole role = PlayerRole.player,
    String? password,
  }) => _service.joinRoom(roomId, role: role, password: password);

  @override
  Future<void> markDisconnected(String roomId) =>
      _service.markDisconnected(roomId);

  @override
  Future<void> addQuestion({
    required String roomId,
    required QuestionDraft draft,
  }) => _service.addQuestion(roomId: roomId, draft: draft);

  @override
  Future<void> updateQuestion({
    required String roomId,
    required String questionId,
    required QuestionDraft draft,
  }) => _service.updateQuestion(
    roomId: roomId,
    questionId: questionId,
    draft: draft,
  );

  @override
  Future<void> deleteQuestion({
    required String roomId,
    required String questionId,
  }) => _service.deleteQuestion(roomId: roomId, questionId: questionId);

  @override
  Future<void> addQuestions({
    required String roomId,
    required List<QuestionDraft> drafts,
  }) => _service.addQuestions(roomId: roomId, drafts: drafts);

  @override
  Future<void> setPlayerRole({
    required String roomId,
    required String targetUid,
    required PlayerRole role,
  }) =>
      _service.setPlayerRole(roomId: roomId, targetUid: targetUid, role: role);

  @override
  Future<void> kickPlayer({
    required String roomId,
    required String targetUid,
  }) => _service.kickPlayer(roomId: roomId, targetUid: targetUid);

  @override
  Future<void> banPlayer({
    required String roomId,
    required String targetUid,
    String reason = '',
  }) =>
      _service.banPlayer(roomId: roomId, targetUid: targetUid, reason: reason);

  @override
  Future<void> unbanPlayer({
    required String roomId,
    required String targetUid,
  }) => _service.unbanPlayer(roomId: roomId, targetUid: targetUid);

  @override
  Future<PackSummary> savePack({
    required String roomId,
    required String name,
  }) => _service.savePack(roomId: roomId, name: name);

  @override
  Future<List<PackSummary>> listPacks() => _service.listPacks();

  @override
  Future<void> applyPack({required String roomId, required String packId}) =>
      _service.applyPack(roomId: roomId, packId: packId);

  @override
  Future<void> startGame(String roomId) => _service.startGame(roomId);

  @override
  Future<void> advanceToRound2(String roomId) =>
      _service.advanceToRound2(roomId);

  @override
  Future<void> startFinalRound(String roomId) =>
      _service.startFinalRound(roomId);

  @override
  Future<void> setFinalQuestion({
    required String roomId,
    required String theme,
    required String question,
    required String answer,
  }) => _service.setFinalQuestion(
    roomId: roomId,
    theme: theme,
    question: question,
    answer: answer,
  );

  @override
  Future<void> selectFinalThemeDeleter({
    required String roomId,
    required String targetUid,
  }) => _service.selectFinalThemeDeleter(roomId: roomId, targetUid: targetUid);

  @override
  Future<void> deleteFinalTheme({
    required String roomId,
    required String theme,
  }) => _service.deleteFinalTheme(roomId: roomId, theme: theme);

  @override
  Future<void> openFinalWagers(String roomId) =>
      _service.openFinalWagers(roomId);

  @override
  Future<void> openFinalAnswers(String roomId) =>
      _service.openFinalAnswers(roomId);

  @override
  Future<void> submitFinalWager({required String roomId, required int wager}) =>
      _service.submitFinalWager(roomId: roomId, wager: wager);

  @override
  Future<void> submitFinalAnswer({
    required String roomId,
    required String answer,
  }) => _service.submitFinalAnswer(roomId: roomId, answer: answer);

  @override
  Future<void> setFinalPlayerResult({
    required String roomId,
    required String targetUid,
    required FinalResult result,
  }) => _service.setFinalPlayerResult(
    roomId: roomId,
    targetUid: targetUid,
    result: result,
  );

  @override
  Future<void> revealFinal(String roomId) => _service.revealFinal(roomId);

  @override
  Future<void> pickQuestion({
    required String roomId,
    required String questionId,
  }) => _service.pickQuestion(roomId: roomId, questionId: questionId);

  @override
  Future<void> openBuzzing(String roomId) => _service.openBuzzing(roomId);

  @override
  Future<void> selectCatTarget(String roomId, String targetUid) =>
      _service.selectCatTarget(roomId, targetUid);

  @override
  Future<void> setWagerAndOpen({required String roomId, required int wager}) =>
      _service.setWagerAndOpen(roomId: roomId, wager: wager);

  @override
  Future<void> buzz(String roomId) => _service.buzz(roomId);

  @override
  Future<void> submitAnswer(String roomId) => _service.submitAnswer(roomId);

  @override
  Future<void> submitNumericAnswer({
    required String roomId,
    required num value,
  }) => _service.submitNumericAnswer(roomId: roomId, value: value);

  @override
  Future<void> judgeAnswer({required String roomId, required bool correct}) =>
      _service.judgeAnswer(roomId: roomId, correct: correct);

  @override
  Future<void> applyScore({
    required String roomId,
    required String targetUid,
    required int delta,
  }) => _service.applyScore(roomId: roomId, targetUid: targetUid, delta: delta);

  @override
  Future<void> pauseGame(String roomId) => _service.pauseGame(roomId);

  @override
  Future<void> resumeGame(String roomId) => _service.resumeGame(roomId);

  @override
  Future<void> handleTimerExpiration(String roomId) =>
      _service.handleTimerExpiration(roomId);
}
