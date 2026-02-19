import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:si_game_flutter/features/game/application/game_providers.dart';
import 'package:si_game_flutter/features/game/game_models.dart';
import 'package:si_game_flutter/features/game/presentation/widgets/room_top_bar.dart';
import 'package:si_game_flutter/l10n/app_localizations.dart';

class _NoopGameActionsController extends GameActionsController {
  @override
  Future<void> build() async {}
}

RoomModel _room({
  required GameStatus status,
  required GamePhase phase,
  required int currentRound,
  String hostUid = 'host-1',
}) {
  return RoomModel(
    id: 'room-1',
    name: 'Room',
    passwordProtected: false,
    hostUid: hostUid,
    status: status,
    phase: phase,
    currentRound: currentRound,
    chooserUid: null,
    pausedByUid: null,
    currentQuestionId: null,
    activeQuestion: null,
    timerDeadlineAtMs: null,
    timerRemainingMs: null,
    buzzQueue: const <String>[],
    currentAttemptUid: null,
    pendingAnswer: null,
    targetedUid: null,
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

Future<void> _pump(
  WidgetTester tester, {
  required RoomModel room,
  required bool isHost,
  bool? canResume,
  bool? canPause,
  bool? canEdit,
}) async {
  final actions = _NoopGameActionsController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomActionsProvider.overrideWithValue(RoomActions(actions)),
        questionActionsProvider.overrideWithValue(QuestionActions(actions)),
        playersStreamProvider.overrideWith(
          (ref, roomId) => Stream.value(const <PlayerModel>[]),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RoomTopBar(
            room: room,
            isHost: isHost,
            canResume: canResume ?? isHost,
            canPause: canPause ?? isHost,
            canEdit: canEdit ?? isHost,
            roomId: 'room-1',
            onOpenEditor: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('start button enabled only for host in lobby', (tester) async {
    await _pump(
      tester,
      room: _room(
        status: GameStatus.lobby,
        phase: GamePhase.lobby,
        currentRound: 1,
      ),
      isHost: true,
    );
    var button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('room_start_game_button')),
    );
    expect(button.onPressed, isNotNull);

    await _pump(
      tester,
      room: _room(
        status: GameStatus.lobby,
        phase: GamePhase.lobby,
        currentRound: 1,
      ),
      isHost: false,
    );
    button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('room_start_game_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('round2 disabled when already in round2', (tester) async {
    await _pump(
      tester,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.boardSelect,
        currentRound: 2,
      ),
      isHost: true,
    );
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('room_round2_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('round2 enabled for host in round1 active game', (tester) async {
    await _pump(
      tester,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.boardSelect,
        currentRound: 1,
      ),
      isHost: true,
    );
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('room_round2_button')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('final-round button disabled in paused/final/completed', (
    tester,
  ) async {
    await _pump(
      tester,
      room: _room(
        status: GameStatus.paused,
        phase: GamePhase.boardSelect,
        currentRound: 1,
      ),
      isHost: true,
    );
    var button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('room_start_final_round_button')),
    );
    expect(button.onPressed, isNull);

    await _pump(
      tester,
      room: _room(
        status: GameStatus.finalRound,
        phase: GamePhase.finalSetup,
        currentRound: 3,
      ),
      isHost: true,
    );
    button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('room_start_final_round_button')),
    );
    expect(button.onPressed, isNull);

    await _pump(
      tester,
      room: _room(
        status: GameStatus.completed,
        phase: GamePhase.gameOver,
        currentRound: 3,
      ),
      isHost: true,
    );
    button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('room_start_final_round_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('final-round button disabled for non-host', (tester) async {
    await _pump(
      tester,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.boardSelect,
        currentRound: 1,
      ),
      isHost: false,
      canPause: false,
      canResume: false,
      canEdit: false,
    );
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('room_start_final_round_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('pause button disabled when canPause is false', (tester) async {
    await _pump(
      tester,
      room: _room(
        status: GameStatus.inGame,
        phase: GamePhase.boardSelect,
        currentRound: 1,
      ),
      isHost: false,
      canPause: false,
      canResume: false,
    );
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('room_pause_resume_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('resume button disabled when paused and canResume is false', (
    tester,
  ) async {
    await _pump(
      tester,
      room: _room(
        status: GameStatus.paused,
        phase: GamePhase.boardSelect,
        currentRound: 1,
      ),
      isHost: false,
      canResume: false,
      canPause: false,
    );
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('room_pause_resume_button')),
    );
    expect(button.onPressed, isNull);
  });
}
