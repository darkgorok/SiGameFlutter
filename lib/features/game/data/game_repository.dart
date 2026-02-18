import '../game_models.dart';

abstract class GameRepository {
  Stream<List<RoomModel>> watchRooms();
  Stream<List<RoomModel>> watchRoomsLimited({required int limit});
  Future<RoomsPageModel> fetchRoomsPage({
    required int limit,
    int? startAfterCreatedAtMs,
  });
  Stream<RoomModel?> watchRoom(String roomId);
  Stream<List<PlayerModel>> watchPlayers(String roomId);
  Stream<List<QuestionModel>> watchQuestions(String roomId);
  Stream<List<GameEventModel>> watchEvents(String roomId);

  Future<void> upsertProfile({
    required String uid,
    required String nickname,
    required String avatarUrl,
  });

  Future<String> createRoom({required String roomName, String? password});
  Future<void> joinRoom(
    String roomId, {
    PlayerRole role = PlayerRole.player,
    String? password,
  });
  Future<void> markDisconnected(String roomId);

  Future<void> addQuestion({
    required String roomId,
    required QuestionDraft draft,
  });
  Future<void> addQuestions({
    required String roomId,
    required List<QuestionDraft> drafts,
  });
  Future<void> setPlayerRole({
    required String roomId,
    required String targetUid,
    required PlayerRole role,
  });
  Future<void> kickPlayer({required String roomId, required String targetUid});
  Future<void> banPlayer({
    required String roomId,
    required String targetUid,
    String reason,
  });
  Future<void> unbanPlayer({required String roomId, required String targetUid});
  Future<PackSummary> savePack({required String roomId, required String name});
  Future<List<PackSummary>> listPacks();
  Future<void> applyPack({required String roomId, required String packId});

  Future<void> startGame(String roomId);
  Future<void> advanceToRound2(String roomId);
  Future<void> startFinalRound(String roomId);
  Future<void> setFinalQuestion({
    required String roomId,
    required String theme,
    required String question,
    required String answer,
  });
  Future<void> openFinalWagers(String roomId);
  Future<void> openFinalAnswers(String roomId);
  Future<void> submitFinalWager({required String roomId, required int wager});
  Future<void> setFinalPlayerResult({
    required String roomId,
    required String targetUid,
    required FinalResult result,
  });
  Future<void> revealFinal(String roomId);

  Future<void> pickQuestion({
    required String roomId,
    required String questionId,
  });
  Future<void> openBuzzing(String roomId);
  Future<void> selectCatTarget(String roomId, String targetUid);
  Future<void> setWagerAndOpen({required String roomId, required int wager});
  Future<void> buzz(String roomId);
  Future<void> submitAnswer(String roomId);
  Future<void> submitNumericAnswer({
    required String roomId,
    required num value,
  });
  Future<void> judgeAnswer({required String roomId, required bool correct});

  Future<void> applyScore({
    required String roomId,
    required String targetUid,
    required int delta,
  });
  Future<void> pauseGame(String roomId);
  Future<void> resumeGame(String roomId);
  Future<void> handleTimerExpiration(String roomId);
}
