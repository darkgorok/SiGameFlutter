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
  Future<String> createRoom({required String roomName}) =>
      _service.createRoom(roomName: roomName);

  @override
  Future<void> joinRoom(String roomId) => _service.joinRoom(roomId);

  @override
  Future<void> markDisconnected(String roomId) =>
      _service.markDisconnected(roomId);

  @override
  Future<void> addQuestion({
    required String roomId,
    required QuestionDraft draft,
  }) => _service.addQuestion(roomId: roomId, draft: draft);

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
  Future<void> submitAnswer(String roomId, String answer) =>
      _service.submitAnswer(roomId, answer);

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
