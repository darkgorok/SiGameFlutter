import 'package:flutter_test/flutter_test.dart';
import 'package:si_game_flutter/features/game/game_models.dart';
import 'package:si_game_flutter/features/game/presentation/controllers/game_ui_permissions.dart';

RoomModel _room({
  required GameStatus status,
  required GamePhase phase,
  String hostUid = 'host-1',
  String? chooserUid = 'p1',
  ActiveQuestion? activeQuestion,
  List<String> buzzQueue = const <String>[],
  String? currentAttemptUid,
  String? targetedUid,
}) {
  return RoomModel(
    id: 'room-1',
    name: 'Room',
    passwordProtected: false,
    hostUid: hostUid,
    status: status,
    phase: phase,
    currentRound: 1,
    chooserUid: chooserUid,
    pausedByUid: null,
    currentQuestionId: activeQuestion?.id,
    activeQuestion: activeQuestion,
    timerDeadlineAtMs: null,
    timerRemainingMs: null,
    buzzQueue: buzzQueue,
    currentAttemptUid: currentAttemptUid,
    pendingAnswer: null,
    targetedUid: targetedUid,
    wagerValue: null,
    finalTheme: null,
    finalQuestion: null,
    finalAnswer: null,
    finalThemePool: const <String>[],
    finalThemeDeleteOrder: const <String>[],
    finalThemeDeleteCandidates: const <String>[],
    finalThemeDeleteNeedsSelection: false,
    finalThemeDeleteIndex: 0,
    finalThemeDeleteCurrentUid: null,
    finalAnswerOrder: const <String>[],
    finalAnswerIndex: 0,
    finalAnswerCurrentUid: null,
    finalRevealOrder: const <String>[],
    finalRevealIndex: 0,
    finalRevealCurrentUid: null,
    finalEligibleUids: const <String>[],
  );
}

void main() {
  test('canPickQuestion allows only host/chooser in board_select', () {
    final room = _room(status: GameStatus.inGame, phase: GamePhase.boardSelect);
    expect(GameUiPermissions.canPickQuestion(room, 'p1'), isTrue);
    expect(GameUiPermissions.canPickQuestion(room, 'host-1'), isTrue);
    expect(GameUiPermissions.canPickQuestion(room, 'p2'), isFalse);
  });

  test('canPickQuestion blocks paused and non-board phases', () {
    final paused = _room(
      status: GameStatus.paused,
      phase: GamePhase.boardSelect,
    );
    final answering = _room(
      status: GameStatus.inGame,
      phase: GamePhase.answering,
    );
    expect(GameUiPermissions.canPickQuestion(paused, 'host-1'), isFalse);
    expect(GameUiPermissions.canPickQuestion(answering, 'host-1'), isFalse);
  });

  test('canBuzz enforces phase/attempt/queue/target restrictions', () {
    final normalQuestion = ActiveQuestion(
      id: 'q1',
      theme: 'T',
      text: 'Q',
      answer: '',
      cost: 100,
      type: QuestionType.normal,
      mediaUrl: '',
      mediaType: QuestionMediaType.none,
      aliases: const <String>[],
    );
    final room = _room(
      status: GameStatus.inGame,
      phase: GamePhase.answering,
      activeQuestion: normalQuestion,
    );
    expect(GameUiPermissions.canBuzz(room, 'p1'), isTrue);
    expect(
      GameUiPermissions.canBuzz(
        _room(
          status: GameStatus.inGame,
          phase: GamePhase.answering,
          activeQuestion: normalQuestion,
          currentAttemptUid: 'p1',
        ),
        'p2',
      ),
      isFalse,
    );
    expect(
      GameUiPermissions.canBuzz(
        _room(
          status: GameStatus.inGame,
          phase: GamePhase.answering,
          activeQuestion: normalQuestion,
          buzzQueue: const <String>['p1'],
        ),
        'p1',
      ),
      isFalse,
    );
    expect(
      GameUiPermissions.canBuzz(
        _room(
          status: GameStatus.inGame,
          phase: GamePhase.answering,
          activeQuestion: normalQuestion,
          targetedUid: 'p2',
        ),
        'p1',
      ),
      isFalse,
    );
  });
}
