import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:si_game_flutter/features/game/application/game_providers.dart';
import 'package:si_game_flutter/features/game/game_models.dart';
import 'package:si_game_flutter/features/game/presentation/controllers/room_auto_flow_controller.dart';

class _SpyGameActionsController extends GameActionsController {
  final List<String> calls = <String>[];
  int? lastWager;
  int? lastSetWager;
  String? lastQuestionId;
  String? lastFinalTargetUid;
  String? lastCatTargetUid;
  FinalResult? lastFinalResult;
  bool? lastJudgeCorrect;

  @override
  Future<void> build() async {}

  @override
  Future<void> startGame(String roomId) async {
    calls.add('startGame:$roomId');
  }

  @override
  Future<void> advanceToRound2(String roomId) async {
    calls.add('advanceToRound2:$roomId');
  }

  @override
  Future<void> startFinalRound(String roomId) async {
    calls.add('startFinalRound:$roomId');
  }

  @override
  Future<void> pickQuestion({
    required String roomId,
    required String questionId,
  }) async {
    lastQuestionId = questionId;
    calls.add('pickQuestion:$roomId');
  }

  @override
  Future<void> submitFinalWager({
    required String roomId,
    required int wager,
  }) async {
    lastWager = wager;
    calls.add('submitFinalWager:$roomId');
  }

  @override
  Future<void> openFinalAnswers(String roomId) async {
    calls.add('openFinalAnswers:$roomId');
  }

  @override
  Future<void> submitFinalAnswer({
    required String roomId,
    required String answer,
  }) async {
    calls.add('submitFinalAnswer:$roomId');
  }

  @override
  Future<void> revealFinal(String roomId) async {
    calls.add('revealFinal:$roomId');
  }

  @override
  Future<void> setFinalPlayerResult({
    required String roomId,
    required String targetUid,
    required FinalResult result,
  }) async {
    lastFinalTargetUid = targetUid;
    lastFinalResult = result;
    calls.add('setFinalPlayerResult:$roomId');
  }

  @override
  Future<void> openBuzzing(String roomId) async {
    calls.add('openBuzzing:$roomId');
  }

  @override
  Future<void> handleTimerExpiration(String roomId) async {
    calls.add('handleTimerExpiration:$roomId');
  }

  @override
  Future<void> selectCatTarget(String roomId, String targetUid) async {
    lastCatTargetUid = targetUid;
    calls.add('selectCatTarget:$roomId');
  }

  @override
  Future<void> setWagerAndOpen({
    required String roomId,
    required int wager,
  }) async {
    lastSetWager = wager;
    calls.add('setWagerAndOpen:$roomId');
  }

  @override
  Future<void> judgeAnswer({
    required String roomId,
    required bool correct,
  }) async {
    lastJudgeCorrect = correct;
    calls.add('judgeAnswer:$roomId');
  }
}

RoomModel _room({
  required GameStatus status,
  required GamePhase phase,
  int round = 1,
  String? chooserUid,
  String? currentAttemptUid,
  String? finalAnswerCurrentUid,
  List<String> finalEligibleUids = const <String>[],
  String? finalAnswer,
  int? timerDeadlineAtMs,
  ActiveQuestion? activeQuestion,
}) {
  return RoomModel(
    id: 'room-1',
    name: 'Room',
    passwordProtected: false,
    hostUid: 'host-1',
    status: status,
    phase: phase,
    currentRound: round,
    chooserUid: chooserUid,
    pausedByUid: null,
    currentQuestionId: null,
    activeQuestion: activeQuestion,
    timerDeadlineAtMs: timerDeadlineAtMs,
    timerRemainingMs: null,
    buzzQueue: const <String>[],
    currentAttemptUid: currentAttemptUid,
    pendingAnswer: null,
    targetedUid: null,
    wagerValue: null,
    finalTheme: null,
    finalQuestion: null,
    finalAnswer: finalAnswer,
    finalThemePool: const <String>[],
    finalThemeDeleteOrder: const <String>[],
    finalThemeDeleteCandidates: const <String>[],
    finalThemeDeleteNeedsSelection: false,
    finalThemeDeleteIndex: 0,
    finalThemeDeleteCurrentUid: null,
    finalAnswerOrder: const <String>[],
    finalAnswerIndex: 0,
    finalAnswerCurrentUid: finalAnswerCurrentUid,
    finalRevealOrder: const <String>[],
    finalRevealIndex: 0,
    finalRevealCurrentUid: null,
    finalEligibleUids: finalEligibleUids,
  );
}

ActiveQuestion _activeQuestion({String id = 'aq1'}) {
  return ActiveQuestion(
    id: id,
    theme: 'Theme',
    text: 'Text',
    answer: 'Answer',
    cost: 100,
    type: QuestionType.normal,
    mediaUrl: '',
    mediaType: QuestionMediaType.none,
    aliases: const <String>[],
  );
}

QuestionModel _question({
  required String id,
  required int round,
  bool used = false,
  String theme = 'Theme',
  int cost = 100,
}) {
  return QuestionModel(
    id: id,
    theme: theme,
    text: 'Text',
    answer: 'Answer',
    cost: cost,
    round: round,
    used: used,
    type: QuestionType.normal,
    mediaUrl: '',
    mediaType: QuestionMediaType.none,
    aliases: const <String>[],
  );
}

PlayerModel _player({
  required String uid,
  PlayerRole role = PlayerRole.player,
  int score = 100,
  bool connected = true,
  bool finalWagerSubmitted = false,
  bool finalAnswerSubmitted = false,
  String? finalAnswerText,
  FinalResult finalResult = FinalResult.pending,
}) {
  return PlayerModel(
    uid: uid,
    nickname: uid,
    avatarUrl: '',
    role: role,
    score: score,
    connected: connected,
    correctAnswers: 0,
    wrongAnswers: 0,
    buzzCount: 0,
    finalWager: 0,
    finalWagerSubmitted: finalWagerSubmitted,
    finalAnswerSubmitted: finalAnswerSubmitted,
    finalAnswerText: finalAnswerText,
    finalResult: finalResult,
    finalRevealed: false,
  );
}

void _driveAndRun({
  required RoomAutoFlowController controller,
  required RoomModel room,
  required List<PlayerModel> players,
  required List<QuestionModel> questions,
  required String uid,
  required PlayerRole myRole,
  required bool isHost,
  required RoomActions roomActions,
  required QuestionActions questionActions,
  required FinalActions finalActions,
}) {
  fakeAsync((async) {
    controller.drive(
      mounted: true,
      uid: uid,
      room: room,
      players: players,
      questions: questions,
      myRole: myRole,
      isHost: isHost,
      roomId: 'room-1',
      roomActions: roomActions,
      questionActions: questionActions,
      finalActions: finalActions,
    );
    async.elapse(const Duration(seconds: 3));
    async.flushMicrotasks();
  });
}

void _driveTwiceQuicklyAndRun({
  required RoomAutoFlowController controller,
  required RoomModel room,
  required List<PlayerModel> players,
  required List<QuestionModel> questions,
  required String uid,
  required PlayerRole myRole,
  required bool isHost,
  required RoomActions roomActions,
  required QuestionActions questionActions,
  required FinalActions finalActions,
}) {
  fakeAsync((async) {
    controller.drive(
      mounted: true,
      uid: uid,
      room: room,
      players: players,
      questions: questions,
      myRole: myRole,
      isHost: isHost,
      roomId: 'room-1',
      roomActions: roomActions,
      questionActions: questionActions,
      finalActions: finalActions,
    );
    controller.drive(
      mounted: true,
      uid: uid,
      room: room,
      players: players,
      questions: questions,
      myRole: myRole,
      isHost: isHost,
      roomId: 'room-1',
      roomActions: roomActions,
      questionActions: questionActions,
      finalActions: finalActions,
    );
    async.elapse(const Duration(seconds: 3));
    async.flushMicrotasks();
  });
}

void main() {
  test('does nothing when auto flow is disabled', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: false);
    _driveAndRun(
      controller: controller,
      room: _room(status: GameStatus.lobby, phase: GamePhase.lobby),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: <QuestionModel>[_question(id: 'q1', round: 1)],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, isEmpty);
  });

  test('does nothing when user is not host', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(status: GameStatus.lobby, phase: GamePhase.lobby),
      players: <PlayerModel>[_player(uid: 'p1', role: PlayerRole.player)],
      questions: <QuestionModel>[_question(id: 'q1', round: 1)],
      uid: 'p1',
      myRole: PlayerRole.player,
      isHost: false,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, isEmpty);
  });

  test('does nothing while game is paused', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(status: GameStatus.paused, phase: GamePhase.boardSelect),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: <QuestionModel>[_question(id: 'q1', round: 1)],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, isEmpty);
  });

  test('lobby with questions auto-starts game', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(status: GameStatus.lobby, phase: GamePhase.lobby),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: <QuestionModel>[_question(id: 'q1', round: 1)],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('startGame:room-1'));
  });

  test('deduplicates same queued action during retry delay', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveTwiceQuicklyAndRun(
      controller: controller,
      room: _room(status: GameStatus.lobby, phase: GamePhase.lobby),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: <QuestionModel>[_question(id: 'q1', round: 1)],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    final startCalls = spy.calls.where((c) => c == 'startGame:room-1').length;
    expect(startCalls, 1);
  });

  test('phase signature change resets action dedupe key', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    fakeAsync((async) {
      controller.drive(
        mounted: true,
        uid: 'host-1',
        room: _room(status: GameStatus.lobby, phase: GamePhase.lobby),
        players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
        questions: <QuestionModel>[_question(id: 'q1', round: 1)],
        myRole: PlayerRole.host,
        isHost: true,
        roomId: 'room-1',
        roomActions: RoomActions(spy),
        questionActions: QuestionActions(spy),
        finalActions: FinalActions(spy),
      );
      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();

      controller.drive(
        mounted: true,
        uid: 'host-1',
        room: _room(
          status: GameStatus.inGame,
          phase: GamePhase.boardSelect,
          round: 1,
        ),
        players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
        questions: const <QuestionModel>[],
        myRole: PlayerRole.host,
        isHost: true,
        roomId: 'room-1',
        roomActions: RoomActions(spy),
        questionActions: QuestionActions(spy),
        finalActions: FinalActions(spy),
      );
      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();
    });

    expect(spy.calls, contains('startGame:room-1'));
    expect(spy.calls, contains('startFinalRound:room-1'));
  });

  test(
    'board_select without current round questions auto-advances to round2',
    () {
      final spy = _SpyGameActionsController();
      final controller = RoomAutoFlowController(enabled: true);
      _driveAndRun(
        controller: controller,
        room: _room(
          status: GameStatus.inGame,
          phase: GamePhase.boardSelect,
          round: 1,
        ),
        players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
        questions: <QuestionModel>[_question(id: 'q2', round: 2)],
        uid: 'host-1',
        myRole: PlayerRole.host,
        isHost: true,
        roomActions: RoomActions(spy),
        questionActions: QuestionActions(spy),
        finalActions: FinalActions(spy),
      );
      expect(spy.calls, contains('advanceToRound2:room-1'));
    },
  );

  test('board_select without remaining questions starts final round', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.boardSelect,
        round: 2,
      ),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('startFinalRound:room-1'));
  });

  test(
    'board_select in round2 with only higher-round leftovers starts final round',
    () {
      final spy = _SpyGameActionsController();
      final controller = RoomAutoFlowController(enabled: true);
      _driveAndRun(
        controller: controller,
        room: _room(
          status: GameStatus.inGame,
          phase: GamePhase.boardSelect,
          round: 2,
        ),
        players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
        questions: <QuestionModel>[
          _question(id: 'q-r3', round: 3, used: false),
        ],
        uid: 'host-1',
        myRole: PlayerRole.host,
        isHost: true,
        roomActions: RoomActions(spy),
        questionActions: QuestionActions(spy),
        finalActions: FinalActions(spy),
      );
      expect(spy.calls, contains('startFinalRound:room-1'));
      expect(
        spy.calls.where((c) => c == 'advanceToRound2:room-1').isEmpty,
        isTrue,
      );
    },
  );

  test('board_select picks sorted question by theme then cost', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.boardSelect,
        round: 1,
      ),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: <QuestionModel>[
        _question(id: 'q-z-100', round: 1, theme: 'Z', cost: 100),
        _question(id: 'q-a-300', round: 1, theme: 'A', cost: 300),
        _question(id: 'q-a-100', round: 1, theme: 'A', cost: 100),
        _question(id: 'q-r2', round: 2, theme: 'A', cost: 10),
      ],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('pickQuestion:room-1'));
    expect(spy.lastQuestionId, 'q-a-100');
  });

  test('question_reveal opens buzzing before timer expiry', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.questionReveal,
        round: 1,
        timerDeadlineAtMs: DateTime.now().millisecondsSinceEpoch + 60 * 1000,
        activeQuestion: _activeQuestion(),
      ),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('openBuzzing:room-1'));
  });

  test('question_reveal handles timer expiration when deadline passed', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.questionReveal,
        round: 1,
        timerDeadlineAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
        activeQuestion: _activeQuestion(),
      ),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('handleTimerExpiration:room-1'));
  });

  test('cat_targeting selects non-chooser active voice player', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.catTargeting,
        round: 1,
        chooserUid: 'host-1',
      ),
      players: <PlayerModel>[
        _player(uid: 'host-1', role: PlayerRole.host, connected: true),
        _player(uid: 'p1', role: PlayerRole.player, connected: true),
        _player(uid: 's1', role: PlayerRole.spectator, connected: true),
      ],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('selectCatTarget:room-1'));
    expect(spy.lastCatTargetUid, 'p1');
  });

  test('cat_targeting times out when no active voice candidates', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.catTargeting,
        round: 1,
        chooserUid: 'host-1',
        timerDeadlineAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
      ),
      players: <PlayerModel>[
        _player(uid: 'host-1', role: PlayerRole.host, connected: false),
        _player(uid: 's1', role: PlayerRole.spectator, connected: true),
      ],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('handleTimerExpiration:room-1'));
  });

  test('wager_bidding sets wager and opens before timer expiry', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.wagerBidding,
        round: 1,
        timerDeadlineAtMs: DateTime.now().millisecondsSinceEpoch + 60 * 1000,
        activeQuestion: _activeQuestion(id: 'w1'),
      ),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('setWagerAndOpen:room-1'));
    expect(spy.lastSetWager, 100);
  });

  test('wager_bidding handles timer expiration when deadline passed', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.wagerBidding,
        round: 1,
        timerDeadlineAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
        activeQuestion: _activeQuestion(id: 'w1'),
      ),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('handleTimerExpiration:room-1'));
  });

  test('answer_review auto-judges true before timer expiry', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.answerReview,
        round: 1,
        timerDeadlineAtMs: DateTime.now().millisecondsSinceEpoch + 60 * 1000,
        activeQuestion: _activeQuestion(id: 'a1'),
      ),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('judgeAnswer:room-1'));
    expect(spy.lastJudgeCorrect, isTrue);
  });

  test('answer_review handles timer expiration when deadline passed', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.answerReview,
        round: 1,
        timerDeadlineAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
        activeQuestion: _activeQuestion(id: 'a1'),
      ),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('handleTimerExpiration:room-1'));
  });

  test('final_wagering submits wager for eligible player and caps at 300', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.finalRound,
        phase: GamePhase.finalWagering,
        round: 3,
        finalEligibleUids: const <String>['p1'],
      ),
      players: <PlayerModel>[
        _player(uid: 'host-1', role: PlayerRole.host),
        _player(uid: 'p1', score: 800, finalWagerSubmitted: false),
      ],
      questions: const <QuestionModel>[],
      uid: 'p1',
      myRole: PlayerRole.player,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('submitFinalWager:room-1'));
    expect(spy.lastWager, 300);
  });

  test('final_wagering submits zero wager for non-positive score', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.finalRound,
        phase: GamePhase.finalWagering,
        round: 3,
        finalEligibleUids: const <String>['p1'],
      ),
      players: <PlayerModel>[
        _player(uid: 'host-1', role: PlayerRole.host),
        _player(uid: 'p1', score: 0, finalWagerSubmitted: false),
      ],
      questions: const <QuestionModel>[],
      uid: 'p1',
      myRole: PlayerRole.player,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('submitFinalWager:room-1'));
    expect(spy.lastWager, 0);
  });

  test(
    'final_wagering does not submit wager when eligible player is spectator',
    () {
      final spy = _SpyGameActionsController();
      final controller = RoomAutoFlowController(enabled: true);
      _driveAndRun(
        controller: controller,
        room: _room(
          status: GameStatus.finalRound,
          phase: GamePhase.finalWagering,
          round: 3,
          finalEligibleUids: const <String>['p1'],
        ),
        players: <PlayerModel>[
          _player(uid: 'host-1', role: PlayerRole.host),
          _player(
            uid: 'p1',
            role: PlayerRole.spectator,
            score: 200,
            finalWagerSubmitted: false,
          ),
        ],
        questions: const <QuestionModel>[],
        uid: 'p1',
        myRole: PlayerRole.spectator,
        isHost: true,
        roomActions: RoomActions(spy),
        questionActions: QuestionActions(spy),
        finalActions: FinalActions(spy),
      );
      expect(
        spy.calls.where((c) => c == 'submitFinalWager:room-1').isEmpty,
        isTrue,
      );
    },
  );

  test('final_wagering opens answers when all eligible submitted', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.finalRound,
        phase: GamePhase.finalWagering,
        round: 3,
        finalEligibleUids: const <String>['p1', 'p2'],
      ),
      players: <PlayerModel>[
        _player(uid: 'host-1', role: PlayerRole.host),
        _player(uid: 'p1', finalWagerSubmitted: true),
        _player(uid: 'p2', finalWagerSubmitted: true),
        _player(
          uid: 's1',
          role: PlayerRole.spectator,
          finalWagerSubmitted: false,
        ),
      ],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('openFinalAnswers:room-1'));
  });

  test('final_wagering does not open answers when eligible list is empty', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.finalRound,
        phase: GamePhase.finalWagering,
        round: 3,
        finalEligibleUids: const <String>[],
      ),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(
      spy.calls.where((c) => c.startsWith('openFinalAnswers')).isEmpty,
      isTrue,
    );
  });

  test('final_answering submits answer for current eligible player', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.finalRound,
        phase: GamePhase.finalAnswering,
        round: 3,
        finalEligibleUids: const <String>['p1'],
        finalAnswerCurrentUid: 'p1',
      ),
      players: <PlayerModel>[
        _player(uid: 'host-1', role: PlayerRole.host),
        _player(uid: 'p1', finalAnswerSubmitted: false),
      ],
      questions: const <QuestionModel>[],
      uid: 'p1',
      myRole: PlayerRole.player,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('submitFinalAnswer:room-1'));
  });

  test('final_answering marks submitted matching final answer as correct', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.finalRound,
        phase: GamePhase.finalAnswering,
        round: 3,
        finalEligibleUids: const <String>['p1'],
        finalAnswerCurrentUid: 'p1',
        finalAnswer: 'Paris',
      ),
      players: <PlayerModel>[
        _player(uid: 'host-1', role: PlayerRole.host),
        _player(
          uid: 'p1',
          finalAnswerSubmitted: true,
          finalAnswerText: 'paris',
        ),
      ],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('setFinalPlayerResult:room-1'));
    expect(spy.lastFinalTargetUid, 'p1');
    expect(spy.lastFinalResult, FinalResult.correct);
  });

  test('final_answering marks non-matching final answer as wrong', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.finalRound,
        phase: GamePhase.finalAnswering,
        round: 3,
        finalEligibleUids: const <String>['p1'],
        finalAnswerCurrentUid: 'p1',
        finalAnswer: 'Paris',
      ),
      players: <PlayerModel>[
        _player(uid: 'host-1', role: PlayerRole.host),
        _player(
          uid: 'p1',
          finalAnswerSubmitted: true,
          finalAnswerText: 'London',
        ),
      ],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('setFinalPlayerResult:room-1'));
    expect(spy.lastFinalTargetUid, 'p1');
    expect(spy.lastFinalResult, FinalResult.wrong);
  });

  test('final_answering reveals final when nobody pending', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.finalRound,
        phase: GamePhase.finalAnswering,
        round: 3,
        finalEligibleUids: const <String>['p1', 'p2'],
      ),
      players: <PlayerModel>[
        _player(uid: 'host-1', role: PlayerRole.host),
        _player(uid: 'p1', finalResult: FinalResult.correct),
        _player(uid: 'p2', finalResult: FinalResult.wrong),
      ],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('revealFinal:room-1'));
  });

  test('final_reveal handles timer expiration when deadline passed', () {
    final spy = _SpyGameActionsController();
    final controller = RoomAutoFlowController(enabled: true);
    _driveAndRun(
      controller: controller,
      room: _room(
        status: GameStatus.finalRound,
        phase: GamePhase.finalReveal,
        round: 3,
        timerDeadlineAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
      ),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
      questions: const <QuestionModel>[],
      uid: 'host-1',
      myRole: PlayerRole.host,
      isHost: true,
      roomActions: RoomActions(spy),
      questionActions: QuestionActions(spy),
      finalActions: FinalActions(spy),
    );
    expect(spy.calls, contains('handleTimerExpiration:room-1'));
  });
}
