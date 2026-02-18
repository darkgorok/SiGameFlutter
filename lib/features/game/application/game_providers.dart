import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../game_models.dart';
import 'usecases/game_action_usecases.dart';
import 'usecases/game_read_usecases.dart';

final gameReadUseCasesProvider = Provider<GameReadUseCases>((ref) {
  return GameReadUseCases(ref.watch(gameRepositoryProvider));
});

final gameActionUseCasesProvider = Provider<GameActionUseCases>((ref) {
  return GameActionUseCases(ref.watch(gameRepositoryProvider));
});

final roomsStreamProvider = StreamProvider<List<RoomModel>>((ref) {
  return ref.watch(gameReadUseCasesProvider).watchRooms();
});

final roomStreamProvider = StreamProvider.family<RoomModel?, String>((
  ref,
  roomId,
) {
  return ref.watch(gameReadUseCasesProvider).watchRoom(roomId);
});

final playersStreamProvider = StreamProvider.family<List<PlayerModel>, String>((
  ref,
  roomId,
) {
  return ref.watch(gameReadUseCasesProvider).watchPlayers(roomId);
});

final questionsStreamProvider =
    StreamProvider.family<List<QuestionModel>, String>((ref, roomId) {
      return ref.watch(gameReadUseCasesProvider).watchQuestions(roomId);
    });

final eventsStreamProvider =
    StreamProvider.family<List<GameEventModel>, String>((ref, roomId) {
      return ref.watch(gameReadUseCasesProvider).watchEvents(roomId);
    });

final gameActionsControllerProvider =
    AsyncNotifierProvider<GameActionsController, void>(
      GameActionsController.new,
    );

class GameActionsController extends AsyncNotifier<void> {
  GameActionUseCases get _actions => ref.read(gameActionUseCasesProvider);

  @override
  Future<void> build() async {}

  Future<String> createRoom({
    required String roomName,
    String? password,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _actions.createRoom(roomName: roomName, password: password),
    );
    if (result.hasError) {
      state = AsyncError(
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
      throw result.error!;
    }
    state = const AsyncData(null);
    return result.requireValue;
  }

  Future<void> joinRoom(
    String roomId, {
    PlayerRole role = PlayerRole.player,
    String? password,
  }) async {
    state = await AsyncValue.guard(
      () => _actions.joinRoom(roomId, role: role, password: password),
    );
    if (state.hasError) throw state.error!;
  }

  Future<void> markDisconnected(String roomId) async {
    await _actions.markDisconnected(roomId);
  }

  Future<void> upsertProfile({
    required String uid,
    required String nickname,
    required String avatarUrl,
  }) async {
    state = await AsyncValue.guard(
      () => _actions.upsertProfile(
        uid: uid,
        nickname: nickname,
        avatarUrl: avatarUrl,
      ),
    );
    if (state.hasError) throw state.error!;
  }

  Future<void> addQuestion({
    required String roomId,
    required QuestionDraft draft,
  }) async {
    state = await AsyncValue.guard(
      () => _actions.addQuestion(roomId: roomId, draft: draft),
    );
    if (state.hasError) throw state.error!;
  }

  Future<void> setPlayerRole({
    required String roomId,
    required String targetUid,
    required PlayerRole role,
  }) async => _runVoid(
    () => _actions.setPlayerRole(
      roomId: roomId,
      targetUid: targetUid,
      role: role,
    ),
  );

  Future<void> kickPlayer({
    required String roomId,
    required String targetUid,
  }) async =>
      _runVoid(() => _actions.kickPlayer(roomId: roomId, targetUid: targetUid));

  Future<void> banPlayer({
    required String roomId,
    required String targetUid,
    String reason = '',
  }) async => _runVoid(
    () => _actions.banPlayer(
      roomId: roomId,
      targetUid: targetUid,
      reason: reason,
    ),
  );

  Future<void> unbanPlayer({
    required String roomId,
    required String targetUid,
  }) async => _runVoid(
    () => _actions.unbanPlayer(roomId: roomId, targetUid: targetUid),
  );

  Future<PackSummary> savePack({
    required String roomId,
    required String name,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _actions.savePack(roomId: roomId, name: name),
    );
    if (result.hasError) {
      state = AsyncError(
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
      throw result.error!;
    }
    state = const AsyncData(null);
    return result.requireValue;
  }

  Future<List<PackSummary>> listPacks() => _actions.listPacks();

  Future<void> applyPack({
    required String roomId,
    required String packId,
  }) async =>
      _runVoid(() => _actions.applyPack(roomId: roomId, packId: packId));

  Future<void> startGame(String roomId) async =>
      _runVoid(() => _actions.startGame(roomId));
  Future<void> advanceToRound2(String roomId) async =>
      _runVoid(() => _actions.advanceToRound2(roomId));
  Future<void> startFinalRound(String roomId) async =>
      _runVoid(() => _actions.startFinalRound(roomId));
  Future<void> setFinalQuestion({
    required String roomId,
    required String theme,
    required String question,
    required String answer,
  }) async => _runVoid(
    () => _actions.setFinalQuestion(
      roomId: roomId,
      theme: theme,
      question: question,
      answer: answer,
    ),
  );
  Future<void> openFinalWagers(String roomId) async =>
      _runVoid(() => _actions.openFinalWagers(roomId));
  Future<void> openFinalAnswers(String roomId) async =>
      _runVoid(() => _actions.openFinalAnswers(roomId));
  Future<void> submitFinalWager({
    required String roomId,
    required int wager,
  }) async =>
      _runVoid(() => _actions.submitFinalWager(roomId: roomId, wager: wager));

  Future<void> setFinalPlayerResult({
    required String roomId,
    required String targetUid,
    required FinalResult result,
  }) async => _runVoid(
    () => _actions.setFinalPlayerResult(
      roomId: roomId,
      targetUid: targetUid,
      result: result,
    ),
  );

  Future<void> revealFinal(String roomId) async =>
      _runVoid(() => _actions.revealFinal(roomId));
  Future<void> pickQuestion({
    required String roomId,
    required String questionId,
  }) async => _runVoid(
    () => _actions.pickQuestion(roomId: roomId, questionId: questionId),
  );
  Future<void> openBuzzing(String roomId) async =>
      _runVoid(() => _actions.openBuzzing(roomId));
  Future<void> selectCatTarget(String roomId, String targetUid) async =>
      _runVoid(() => _actions.selectCatTarget(roomId, targetUid));
  Future<void> setWagerAndOpen({
    required String roomId,
    required int wager,
  }) async =>
      _runVoid(() => _actions.setWagerAndOpen(roomId: roomId, wager: wager));
  Future<void> buzz(String roomId) async =>
      _runVoid(() => _actions.buzz(roomId));
  Future<void> submitAnswer(String roomId) async =>
      _runVoid(() => _actions.submitAnswer(roomId));
  Future<void> submitNumericAnswer({
    required String roomId,
    required num value,
  }) async => _runVoid(
    () => _actions.submitNumericAnswer(roomId: roomId, value: value),
  );
  Future<void> judgeAnswer({
    required String roomId,
    required bool correct,
  }) async =>
      _runVoid(() => _actions.judgeAnswer(roomId: roomId, correct: correct));
  Future<void> applyScore({
    required String roomId,
    required String targetUid,
    required int delta,
  }) async => _runVoid(
    () =>
        _actions.applyScore(roomId: roomId, targetUid: targetUid, delta: delta),
  );
  Future<void> pauseGame(String roomId) async =>
      _runVoid(() => _actions.pauseGame(roomId));
  Future<void> resumeGame(String roomId) async =>
      _runVoid(() => _actions.resumeGame(roomId));
  Future<void> handleTimerExpiration(String roomId) async =>
      _runVoid(() => _actions.handleTimerExpiration(roomId));

  Future<void> _runVoid(Future<void> Function() action) async {
    state = await AsyncValue.guard(action);
    if (state.hasError) throw state.error!;
  }
}
