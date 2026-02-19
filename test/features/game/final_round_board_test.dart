import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:si_game_flutter/core/providers.dart';
import 'package:si_game_flutter/features/game/application/game_providers.dart';
import 'package:si_game_flutter/features/game/game_models.dart';
import 'package:si_game_flutter/features/game/presentation/widgets/final_round_board.dart';
import 'package:si_game_flutter/l10n/app_localizations.dart';

RoomModel _room({
  required GamePhase phase,
  required List<String> eligible,
  String? finalTheme = 'Theme',
  String? finalQuestion = 'Question',
  String hostUid = 'host-1',
  String? finalAnswerCurrentUid,
}) {
  return RoomModel(
    id: 'room-1',
    name: 'Room',
    passwordProtected: false,
    hostUid: hostUid,
    status: GameStatus.finalRound,
    phase: phase,
    currentRound: 3,
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
    finalTheme: finalTheme,
    finalQuestion: finalQuestion,
    finalAnswer: 'Answer',
    finalThemePool: const <String>['Theme'],
    finalThemeDeleteOrder: const <String>[],
    finalThemeDeleteCandidates: const <String>[],
    finalThemeDeleteNeedsSelection: false,
    finalThemeDeleteIndex: 0,
    finalThemeDeleteCurrentUid: null,
    finalAnswerOrder: eligible,
    finalAnswerIndex: 0,
    finalAnswerCurrentUid: finalAnswerCurrentUid,
    finalRevealOrder: const <String>[],
    finalRevealIndex: 0,
    finalRevealCurrentUid: null,
    finalEligibleUids: eligible,
  );
}

PlayerModel _player({
  required String uid,
  required PlayerRole role,
  bool finalWagerSubmitted = false,
  bool finalAnswerSubmitted = false,
}) {
  return PlayerModel(
    uid: uid,
    nickname: uid,
    avatarUrl: '',
    role: role,
    score: 100,
    connected: true,
    correctAnswers: 0,
    wrongAnswers: 0,
    buzzCount: 0,
    finalWager: 0,
    finalWagerSubmitted: finalWagerSubmitted,
    finalAnswerSubmitted: finalAnswerSubmitted,
    finalAnswerText: null,
    finalResult: FinalResult.pending,
    finalRevealed: false,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required String uid,
  required RoomModel room,
  required List<PlayerModel> players,
  PlayerRole myRole = PlayerRole.player,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserUidProvider.overrideWith((ref) => uid),
        playersStreamProvider.overrideWith(
          (ref, roomId) => Stream.value(players),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 900,
            child: FinalRoundBoard(
              room: room,
              roomId: 'room-1',
              myRole: myRole,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('host cannot open final answers when eligible list is empty', (
    tester,
  ) async {
    await _pump(
      tester,
      uid: 'host-1',
      room: _room(phase: GamePhase.finalWagering, eligible: const <String>[]),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
    );

    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('final_open_answers_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'host can open final answers when all eligible wagers submitted',
    (tester) async {
      await _pump(
        tester,
        uid: 'host-1',
        room: _room(
          phase: GamePhase.finalWagering,
          eligible: const <String>['p1', 'p2'],
        ),
        players: <PlayerModel>[
          _player(uid: 'host-1', role: PlayerRole.host),
          _player(
            uid: 'p1',
            role: PlayerRole.player,
            finalWagerSubmitted: true,
          ),
          _player(
            uid: 'p2',
            role: PlayerRole.player,
            finalWagerSubmitted: true,
          ),
          _player(
            uid: 's1',
            role: PlayerRole.spectator,
            finalWagerSubmitted: false,
          ),
        ],
      );

      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('final_open_answers_button')),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('eligible player sees wager controls, spectator does not', (
    tester,
  ) async {
    final room = _room(
      phase: GamePhase.finalWagering,
      eligible: const <String>['p1'],
    );
    final players = <PlayerModel>[
      _player(uid: 'p1', role: PlayerRole.player, finalWagerSubmitted: false),
      _player(uid: 's1', role: PlayerRole.spectator),
    ];

    await _pump(
      tester,
      uid: 'p1',
      room: room,
      players: players,
      myRole: PlayerRole.player,
    );
    expect(
      find.byKey(const ValueKey('final_place_wager_button')),
      findsOneWidget,
    );

    await _pump(
      tester,
      uid: 's1',
      room: room,
      players: players,
      myRole: PlayerRole.spectator,
    );
    expect(
      find.byKey(const ValueKey('final_place_wager_button')),
      findsNothing,
    );
  });

  testWidgets(
    'final answering hides submit answer for non-current eligible player',
    (tester) async {
      final room = _room(
        phase: GamePhase.finalAnswering,
        eligible: const <String>['p1', 'p2'],
        finalAnswerCurrentUid: 'p2',
      );
      final players = <PlayerModel>[
        _player(uid: 'p1', role: PlayerRole.player),
        _player(uid: 'p2', role: PlayerRole.player),
      ];

      await _pump(
        tester,
        uid: 'p1',
        room: room,
        players: players,
        myRole: PlayerRole.player,
      );
      expect(
        find.byKey(const ValueKey('final_submit_answer_button')),
        findsNothing,
      );

      expect(
        find.byKey(const ValueKey('final_submit_answer_button')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'final answering shows submit answer for current eligible player',
    (tester) async {
      final room = _room(
        phase: GamePhase.finalAnswering,
        eligible: const <String>['p1', 'p2'],
        finalAnswerCurrentUid: 'p2',
      );
      final players = <PlayerModel>[
        _player(uid: 'p1', role: PlayerRole.player),
        _player(uid: 'p2', role: PlayerRole.player),
      ];

      await _pump(
        tester,
        uid: 'p2',
        room: room,
        players: players,
        myRole: PlayerRole.player,
      );
      expect(
        find.byKey(const ValueKey('final_submit_answer_button')),
        findsOneWidget,
      );
    },
  );
}
