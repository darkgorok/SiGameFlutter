import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:si_game_flutter/core/providers.dart';
import 'package:si_game_flutter/features/game/application/game_providers.dart';
import 'package:si_game_flutter/features/game/game_models.dart';
import 'package:si_game_flutter/features/game/presentation/widgets/question_flow_widgets.dart';
import 'package:si_game_flutter/l10n/app_localizations.dart';

RoomModel _room({
  required GamePhase phase,
  required String hostUid,
  String? chooserUid,
}) {
  return RoomModel(
    id: 'room-1',
    name: 'Room',
    passwordProtected: false,
    hostUid: hostUid,
    status: GameStatus.inGame,
    phase: phase,
    currentRound: 1,
    chooserUid: chooserUid,
    pausedByUid: null,
    currentQuestionId: 'q1',
    activeQuestion: ActiveQuestion(
      id: 'q1',
      theme: 'Theme',
      text: 'Question?',
      answer: 'Answer',
      cost: 100,
      type: QuestionType.normal,
      mediaUrl: '',
      mediaType: QuestionMediaType.none,
      aliases: const <String>[],
    ),
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

PlayerModel _player({required String uid, required PlayerRole role}) {
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
    finalWagerSubmitted: false,
    finalAnswerSubmitted: false,
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
          body: ActiveQuestionPanel(
            room: room,
            roomId: 'room-1',
            myRole: myRole,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('questionReveal hides open button for non-host', (tester) async {
    final room = _room(
      phase: GamePhase.questionReveal,
      hostUid: 'host-1',
      chooserUid: 'p1',
    );
    final players = <PlayerModel>[
      _player(uid: 'host-1', role: PlayerRole.host),
      _player(uid: 'p1', role: PlayerRole.player),
    ];

    await _pump(tester, uid: 'p1', room: room, players: players);
    expect(
      find.byKey(const ValueKey('room_open_buzzing_button')),
      findsNothing,
    );
  });

  testWidgets('questionReveal shows open button for host', (tester) async {
    final room = _room(
      phase: GamePhase.questionReveal,
      hostUid: 'host-1',
      chooserUid: 'p1',
    );
    final players = <PlayerModel>[
      _player(uid: 'host-1', role: PlayerRole.host),
      _player(uid: 'p1', role: PlayerRole.player),
    ];

    await _pump(tester, uid: 'host-1', room: room, players: players);
    expect(
      find.byKey(const ValueKey('room_open_buzzing_button')),
      findsOneWidget,
    );
  });

  testWidgets('catTargeting shows only non-spectator target buttons', (
    tester,
  ) async {
    final room = _room(
      phase: GamePhase.catTargeting,
      hostUid: 'host-1',
      chooserUid: 'p1',
    );
    final players = <PlayerModel>[
      _player(uid: 'host-1', role: PlayerRole.host),
      _player(uid: 'p1', role: PlayerRole.player),
      _player(uid: 's1', role: PlayerRole.spectator),
    ];

    await _pump(tester, uid: 'p1', room: room, players: players);
    expect(
      find.byKey(const ValueKey('room_cat_target_host-1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('room_cat_target_p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('room_cat_target_s1')), findsNothing);
  });

  testWidgets('wager panel button is disabled for non-host and non-chooser', (
    tester,
  ) async {
    final room = _room(
      phase: GamePhase.wagerBidding,
      hostUid: 'host-1',
      chooserUid: 'p1',
    );
    final players = <PlayerModel>[
      _player(uid: 'host-1', role: PlayerRole.host),
      _player(uid: 'p1', role: PlayerRole.player),
      _player(uid: 'p2', role: PlayerRole.player),
    ];

    await _pump(tester, uid: 'p2', room: room, players: players);
    final btn = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('room_confirm_wager_button')),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('wager panel button is enabled for chooser', (tester) async {
    final room = _room(
      phase: GamePhase.wagerBidding,
      hostUid: 'host-1',
      chooserUid: 'p1',
    );
    final players = <PlayerModel>[
      _player(uid: 'host-1', role: PlayerRole.host),
      _player(uid: 'p1', role: PlayerRole.player),
      _player(uid: 'p2', role: PlayerRole.player),
    ];
    await _pump(tester, uid: 'p1', room: room, players: players);
    final btn = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('room_confirm_wager_button')),
    );
    expect(btn.onPressed, isNotNull);
  });
}
