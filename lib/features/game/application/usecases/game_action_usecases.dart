import '../../data/game_repository.dart';
import '../../game_models.dart';

class GameActionUseCases {
  GameActionUseCases(this._repository);

  final GameRepository _repository;

  Future<void> upsertProfile({
    required String uid,
    required String nickname,
    required String avatarUrl,
  }) {
    return _repository.upsertProfile(
      uid: uid,
      nickname: nickname,
      avatarUrl: avatarUrl,
    );
  }

  Future<String> createRoom({required String roomName, String? password}) {
    return _repository.createRoom(roomName: roomName, password: password);
  }

  Future<void> joinRoom(
    String roomId, {
    PlayerRole role = PlayerRole.player,
    String? password,
  }) => _repository.joinRoom(roomId, role: role, password: password);

  Future<void> markDisconnected(String roomId) {
    return _repository.markDisconnected(roomId);
  }

  Future<void> addQuestion({
    required String roomId,
    required QuestionDraft draft,
  }) {
    return _repository.addQuestion(roomId: roomId, draft: draft);
  }

  Future<void> updateQuestion({
    required String roomId,
    required String questionId,
    required QuestionDraft draft,
  }) {
    return _repository.updateQuestion(
      roomId: roomId,
      questionId: questionId,
      draft: draft,
    );
  }

  Future<void> deleteQuestion({
    required String roomId,
    required String questionId,
  }) {
    return _repository.deleteQuestion(roomId: roomId, questionId: questionId);
  }

  Future<void> addQuestions({
    required String roomId,
    required List<QuestionDraft> drafts,
  }) {
    return _repository.addQuestions(roomId: roomId, drafts: drafts);
  }

  Future<void> setPlayerRole({
    required String roomId,
    required String targetUid,
    required PlayerRole role,
  }) {
    return _repository.setPlayerRole(
      roomId: roomId,
      targetUid: targetUid,
      role: role,
    );
  }

  Future<void> kickPlayer({required String roomId, required String targetUid}) {
    return _repository.kickPlayer(roomId: roomId, targetUid: targetUid);
  }

  Future<void> banPlayer({
    required String roomId,
    required String targetUid,
    String reason = '',
  }) {
    return _repository.banPlayer(
      roomId: roomId,
      targetUid: targetUid,
      reason: reason,
    );
  }

  Future<void> unbanPlayer({
    required String roomId,
    required String targetUid,
  }) {
    return _repository.unbanPlayer(roomId: roomId, targetUid: targetUid);
  }

  Future<PackSummary> savePack({required String roomId, required String name}) {
    return _repository.savePack(roomId: roomId, name: name);
  }

  Future<List<PackSummary>> listPacks() => _repository.listPacks();

  Future<void> applyPack({required String roomId, required String packId}) {
    return _repository.applyPack(roomId: roomId, packId: packId);
  }

  Future<void> startGame(String roomId) => _repository.startGame(roomId);
  Future<void> advanceToRound2(String roomId) =>
      _repository.advanceToRound2(roomId);
  Future<void> startFinalRound(String roomId) =>
      _repository.startFinalRound(roomId);
  Future<void> setFinalQuestion({
    required String roomId,
    required String theme,
    required String question,
    required String answer,
  }) {
    return _repository.setFinalQuestion(
      roomId: roomId,
      theme: theme,
      question: question,
      answer: answer,
    );
  }

  Future<void> selectFinalThemeDeleter({
    required String roomId,
    required String targetUid,
  }) =>
      _repository.selectFinalThemeDeleter(roomId: roomId, targetUid: targetUid);
  Future<void> deleteFinalTheme({
    required String roomId,
    required String theme,
  }) => _repository.deleteFinalTheme(roomId: roomId, theme: theme);

  Future<void> openFinalWagers(String roomId) =>
      _repository.openFinalWagers(roomId);
  Future<void> openFinalAnswers(String roomId) =>
      _repository.openFinalAnswers(roomId);
  Future<void> submitFinalWager({required String roomId, required int wager}) {
    return _repository.submitFinalWager(roomId: roomId, wager: wager);
  }

  Future<void> submitFinalAnswer({
    required String roomId,
    required String answer,
  }) {
    return _repository.submitFinalAnswer(roomId: roomId, answer: answer);
  }

  Future<void> setFinalPlayerResult({
    required String roomId,
    required String targetUid,
    required FinalResult result,
  }) {
    return _repository.setFinalPlayerResult(
      roomId: roomId,
      targetUid: targetUid,
      result: result,
    );
  }

  Future<void> revealFinal(String roomId) => _repository.revealFinal(roomId);

  Future<void> pickQuestion({
    required String roomId,
    required String questionId,
  }) {
    return _repository.pickQuestion(roomId: roomId, questionId: questionId);
  }

  Future<void> openBuzzing(String roomId) => _repository.openBuzzing(roomId);
  Future<void> selectCatTarget(String roomId, String targetUid) {
    return _repository.selectCatTarget(roomId, targetUid);
  }

  Future<void> setWagerAndOpen({required String roomId, required int wager}) {
    return _repository.setWagerAndOpen(roomId: roomId, wager: wager);
  }

  Future<void> buzz(String roomId) => _repository.buzz(roomId);
  Future<void> submitAnswer(String roomId) {
    return _repository.submitAnswer(roomId);
  }

  Future<void> submitNumericAnswer({
    required String roomId,
    required num value,
  }) {
    return _repository.submitNumericAnswer(roomId: roomId, value: value);
  }

  Future<void> judgeAnswer({required String roomId, required bool correct}) {
    return _repository.judgeAnswer(roomId: roomId, correct: correct);
  }

  Future<void> applyScore({
    required String roomId,
    required String targetUid,
    required int delta,
  }) {
    return _repository.applyScore(
      roomId: roomId,
      targetUid: targetUid,
      delta: delta,
    );
  }

  Future<void> pauseGame(String roomId) => _repository.pauseGame(roomId);
  Future<void> resumeGame(String roomId) => _repository.resumeGame(roomId);
  Future<void> handleTimerExpiration(String roomId) =>
      _repository.handleTimerExpiration(roomId);
}
