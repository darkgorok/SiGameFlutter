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

final roomsStreamProvider = StreamProvider.autoDispose<List<RoomModel>>((ref) {
  return ref.watch(gameReadUseCasesProvider).watchRooms();
});

final roomStreamProvider = StreamProvider.autoDispose
    .family<RoomModel?, String>((ref, roomId) {
      return ref.watch(gameReadUseCasesProvider).watchRoom(roomId);
    });

final playersStreamProvider = StreamProvider.autoDispose
    .family<List<PlayerModel>, String>((ref, roomId) {
      return ref.watch(gameReadUseCasesProvider).watchPlayers(roomId);
    });

final questionsStreamProvider = StreamProvider.autoDispose
    .family<List<QuestionModel>, String>((ref, roomId) {
      return ref.watch(gameReadUseCasesProvider).watchQuestions(roomId);
    });

final eventsStreamProvider = StreamProvider.autoDispose
    .family<List<GameEventModel>, String>((ref, roomId) {
      return ref.watch(gameReadUseCasesProvider).watchEvents(roomId);
    });

class RoomQuestionsArgs {
  const RoomQuestionsArgs({required this.roomId, required this.round});
  final String roomId;
  final int round;

  @override
  bool operator ==(Object other) {
    return other is RoomQuestionsArgs &&
        other.roomId == roomId &&
        other.round == round;
  }

  @override
  int get hashCode => Object.hash(roomId, round);
}

class GroupedQuestionBoard {
  GroupedQuestionBoard({required this.themes, required this.grouped});
  final List<String> themes;
  final Map<String, List<QuestionModel>> grouped;
}

final groupedQuestionsProvider = Provider.autoDispose
    .family<AsyncValue<GroupedQuestionBoard>, RoomQuestionsArgs>((ref, args) {
      final questionsAsync = ref.watch(questionsStreamProvider(args.roomId));
      return questionsAsync.whenData((allQuestions) {
        final questions = allQuestions.where((q) => q.round == args.round);
        final grouped = <String, List<QuestionModel>>{};
        for (final q in questions) {
          grouped.putIfAbsent(q.theme, () => <QuestionModel>[]).add(q);
        }
        final themes = grouped.keys.toList()..sort();
        for (final values in grouped.values) {
          values.sort((a, b) => a.cost.compareTo(b.cost));
        }
        return GroupedQuestionBoard(themes: themes, grouped: grouped);
      });
    });

class RoomsPaginationState {
  const RoomsPaginationState({
    required this.rooms,
    required this.hasMore,
    required this.loadingMore,
  });

  final List<RoomModel> rooms;
  final bool hasMore;
  final bool loadingMore;

  RoomsPaginationState copyWith({
    List<RoomModel>? rooms,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return RoomsPaginationState(
      rooms: rooms ?? this.rooms,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

final roomsPaginationControllerProvider =
    AsyncNotifierProvider.autoDispose<
      RoomsPaginationController,
      RoomsPaginationState
    >(RoomsPaginationController.new);

class RoomsPaginationController
    extends AutoDisposeAsyncNotifier<RoomsPaginationState> {
  static const _pageSize = 30;
  int? _cursorCreatedAtMs;

  GameReadUseCases get _reads => ref.read(gameReadUseCasesProvider);

  @override
  Future<RoomsPaginationState> build() async {
    final page = await _reads.fetchRoomsPage(limit: _pageSize);
    _cursorCreatedAtMs = page.nextCursorCreatedAtMs;
    return RoomsPaginationState(
      rooms: page.rooms,
      hasMore: page.hasMore,
      loadingMore: false,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    final result = await AsyncValue.guard(
      () => _reads.fetchRoomsPage(
        limit: _pageSize,
        startAfterCreatedAtMs: _cursorCreatedAtMs,
      ),
    );
    if (result.hasError) {
      state = AsyncError(
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
      return;
    }
    final page = result.requireValue;
    _cursorCreatedAtMs = page.nextCursorCreatedAtMs;
    state = AsyncData(
      RoomsPaginationState(
        rooms: <RoomModel>[...current.rooms, ...page.rooms],
        hasMore: page.hasMore,
        loadingMore: false,
      ),
    );
  }
}

final gameActionsControllerProvider =
    AsyncNotifierProvider<GameActionsController, void>(
      GameActionsController.new,
    );

class GameActionsController extends AsyncNotifier<void> {
  GameActionUseCases get _actions => ref.read(gameActionUseCasesProvider);
  final Map<String, PlayerRole> _joinedRooms = <String, PlayerRole>{};

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
    if (password == null && _joinedRooms[roomId] == role) {
      return;
    }
    state = await AsyncValue.guard(
      () => _actions.joinRoom(roomId, role: role, password: password),
    );
    if (state.hasError) {
      throw state.error!;
    }
    _joinedRooms[roomId] = role;
  }

  Future<void> markDisconnected(String roomId) async {
    _joinedRooms.remove(roomId);
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

  Future<void> updateQuestion({
    required String roomId,
    required String questionId,
    required QuestionDraft draft,
  }) async {
    state = await AsyncValue.guard(
      () => _actions.updateQuestion(
        roomId: roomId,
        questionId: questionId,
        draft: draft,
      ),
    );
    if (state.hasError) throw state.error!;
  }

  Future<void> deleteQuestion({
    required String roomId,
    required String questionId,
  }) async {
    state = await AsyncValue.guard(
      () => _actions.deleteQuestion(roomId: roomId, questionId: questionId),
    );
    if (state.hasError) throw state.error!;
  }

  Future<void> addQuestions({
    required String roomId,
    required List<QuestionDraft> drafts,
  }) async {
    state = await AsyncValue.guard(
      () => _actions.addQuestions(roomId: roomId, drafts: drafts),
    );
    if (state.hasError) {
      throw state.error!;
    }
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
  Future<void> deleteFinalTheme({
    required String roomId,
    required String theme,
  }) async =>
      _runVoid(() => _actions.deleteFinalTheme(roomId: roomId, theme: theme));
  Future<void> selectFinalThemeDeleter({
    required String roomId,
    required String targetUid,
  }) async => _runVoid(
    () =>
        _actions.selectFinalThemeDeleter(roomId: roomId, targetUid: targetUid),
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
  Future<void> submitFinalAnswer({
    required String roomId,
    required String answer,
  }) async => _runVoid(
    () => _actions.submitFinalAnswer(roomId: roomId, answer: answer),
  );

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

final roomActionsProvider = Provider<RoomActions>((ref) {
  return RoomActions(ref.read(gameActionsControllerProvider.notifier));
});

final playerActionsProvider = Provider<PlayerActions>((ref) {
  return PlayerActions(ref.read(gameActionsControllerProvider.notifier));
});

final questionActionsProvider = Provider<QuestionActions>((ref) {
  return QuestionActions(ref.read(gameActionsControllerProvider.notifier));
});

final finalActionsProvider = Provider<FinalActions>((ref) {
  return FinalActions(ref.read(gameActionsControllerProvider.notifier));
});

class RoomActions {
  const RoomActions(this._actions);
  final GameActionsController _actions;

  Future<String> createRoom({required String roomName, String? password}) =>
      _actions.createRoom(roomName: roomName, password: password);
  Future<void> joinRoom(
    String roomId, {
    PlayerRole role = PlayerRole.player,
    String? password,
  }) => _actions.joinRoom(roomId, role: role, password: password);
  Future<void> markDisconnected(String roomId) =>
      _actions.markDisconnected(roomId);
  Future<void> pauseGame(String roomId) => _actions.pauseGame(roomId);
  Future<void> resumeGame(String roomId) => _actions.resumeGame(roomId);
  Future<void> startGame(String roomId) => _actions.startGame(roomId);
  Future<void> advanceToRound2(String roomId) =>
      _actions.advanceToRound2(roomId);
  Future<void> startFinalRound(String roomId) =>
      _actions.startFinalRound(roomId);
}

class PlayerActions {
  const PlayerActions(this._actions);
  final GameActionsController _actions;

  Future<void> setPlayerRole({
    required String roomId,
    required String targetUid,
    required PlayerRole role,
  }) =>
      _actions.setPlayerRole(roomId: roomId, targetUid: targetUid, role: role);
  Future<void> kickPlayer({
    required String roomId,
    required String targetUid,
  }) => _actions.kickPlayer(roomId: roomId, targetUid: targetUid);
  Future<void> banPlayer({
    required String roomId,
    required String targetUid,
    String reason = '',
  }) =>
      _actions.banPlayer(roomId: roomId, targetUid: targetUid, reason: reason);
  Future<void> unbanPlayer({
    required String roomId,
    required String targetUid,
  }) => _actions.unbanPlayer(roomId: roomId, targetUid: targetUid);
  Future<void> applyScore({
    required String roomId,
    required String targetUid,
    required int delta,
  }) => _actions.applyScore(roomId: roomId, targetUid: targetUid, delta: delta);
}

class QuestionActions {
  const QuestionActions(this._actions);
  final GameActionsController _actions;

  Future<void> addQuestion({
    required String roomId,
    required QuestionDraft draft,
  }) => _actions.addQuestion(roomId: roomId, draft: draft);
  Future<void> updateQuestion({
    required String roomId,
    required String questionId,
    required QuestionDraft draft,
  }) => _actions.updateQuestion(
    roomId: roomId,
    questionId: questionId,
    draft: draft,
  );
  Future<void> deleteQuestion({
    required String roomId,
    required String questionId,
  }) => _actions.deleteQuestion(roomId: roomId, questionId: questionId);
  Future<void> addQuestions({
    required String roomId,
    required List<QuestionDraft> drafts,
  }) => _actions.addQuestions(roomId: roomId, drafts: drafts);
  Future<void> pickQuestion({
    required String roomId,
    required String questionId,
  }) => _actions.pickQuestion(roomId: roomId, questionId: questionId);
  Future<void> openBuzzing(String roomId) => _actions.openBuzzing(roomId);
  Future<void> selectCatTarget(String roomId, String targetUid) =>
      _actions.selectCatTarget(roomId, targetUid);
  Future<void> setWagerAndOpen({required String roomId, required int wager}) =>
      _actions.setWagerAndOpen(roomId: roomId, wager: wager);
  Future<void> buzz(String roomId) => _actions.buzz(roomId);
  Future<void> submitAnswer(String roomId) => _actions.submitAnswer(roomId);
  Future<void> submitNumericAnswer({
    required String roomId,
    required num value,
  }) => _actions.submitNumericAnswer(roomId: roomId, value: value);
  Future<void> judgeAnswer({required String roomId, required bool correct}) =>
      _actions.judgeAnswer(roomId: roomId, correct: correct);
  Future<void> handleTimerExpiration(String roomId) =>
      _actions.handleTimerExpiration(roomId);
  Future<PackSummary> savePack({
    required String roomId,
    required String name,
  }) => _actions.savePack(roomId: roomId, name: name);
  Future<List<PackSummary>> listPacks() => _actions.listPacks();
  Future<void> applyPack({required String roomId, required String packId}) =>
      _actions.applyPack(roomId: roomId, packId: packId);
}

class FinalActions {
  const FinalActions(this._actions);
  final GameActionsController _actions;

  Future<void> setFinalQuestion({
    required String roomId,
    required String theme,
    required String question,
    required String answer,
  }) => _actions.setFinalQuestion(
    roomId: roomId,
    theme: theme,
    question: question,
    answer: answer,
  );
  Future<void> selectFinalThemeDeleter({
    required String roomId,
    required String targetUid,
  }) => _actions.selectFinalThemeDeleter(roomId: roomId, targetUid: targetUid);
  Future<void> deleteFinalTheme({
    required String roomId,
    required String theme,
  }) => _actions.deleteFinalTheme(roomId: roomId, theme: theme);
  Future<void> openFinalWagers(String roomId) =>
      _actions.openFinalWagers(roomId);
  Future<void> openFinalAnswers(String roomId) =>
      _actions.openFinalAnswers(roomId);
  Future<void> submitFinalWager({required String roomId, required int wager}) =>
      _actions.submitFinalWager(roomId: roomId, wager: wager);
  Future<void> submitFinalAnswer({
    required String roomId,
    required String answer,
  }) => _actions.submitFinalAnswer(roomId: roomId, answer: answer);
  Future<void> setFinalPlayerResult({
    required String roomId,
    required String targetUid,
    required FinalResult result,
  }) => _actions.setFinalPlayerResult(
    roomId: roomId,
    targetUid: targetUid,
    result: result,
  );
  Future<void> revealFinal(String roomId) => _actions.revealFinal(roomId);
}
