import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:si_game_flutter/core/providers.dart';
import 'package:si_game_flutter/features/game/application/game_providers.dart';
import 'package:si_game_flutter/features/game/game_models.dart';
import 'package:si_game_flutter/features/game/presentation/screens/room_screen.dart';
import 'package:si_game_flutter/features/game/presentation/widgets/final_round_board.dart';
import 'package:si_game_flutter/features/game/presentation/widgets/question_flow_widgets.dart';
import 'package:si_game_flutter/features/game/presentation/widgets/room_side_panel.dart';
import 'package:si_game_flutter/features/game/presentation/widgets/room_top_bar.dart';
import 'package:si_game_flutter/l10n/app_localizations.dart';

class _NoopGameActionsController extends GameActionsController {
  @override
  Future<void> build() async {}

  @override
  Future<void> markDisconnected(String roomId) async {}
}

RoomModel _room({required GameStatus status, required GamePhase phase}) {
  return RoomModel(
    id: 'room-1',
    name: 'Room',
    passwordProtected: false,
    hostUid: 'host-1',
    status: status,
    phase: phase,
    currentRound: 1,
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

PlayerModel _player({required String uid, required PlayerRole role}) {
  return PlayerModel(
    uid: uid,
    nickname: uid,
    avatarUrl: '',
    role: role,
    score: 0,
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

QuestionModel _question() {
  return QuestionModel(
    id: 'q1',
    theme: 'Theme',
    text: 'Text',
    answer: 'Answer',
    cost: 100,
    round: 1,
    used: false,
    type: QuestionType.normal,
    mediaUrl: '',
    mediaType: QuestionMediaType.none,
    aliases: const <String>[],
  );
}

GameEventModel _event() {
  return GameEventModel(
    id: 'e1',
    type: 'system',
    message: 'Started',
    actorUid: 'host-1',
    createdAt: DateTime(2025, 1, 1),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required String uid,
  required RoomModel room,
  required List<PlayerModel> players,
  PlayerRole role = PlayerRole.player,
}) async {
  final actions = _NoopGameActionsController();
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserUidProvider.overrideWith((ref) => uid),
        roomStreamProvider.overrideWith((ref, roomId) => Stream.value(room)),
        playersStreamProvider.overrideWith(
          (ref, roomId) => Stream.value(players),
        ),
        questionsStreamProvider.overrideWith(
          (ref, roomId) => Stream.value(<QuestionModel>[_question()]),
        ),
        eventsStreamProvider.overrideWith(
          (ref, roomId) => Stream.value(<GameEventModel>[_event()]),
        ),
        roomActionsProvider.overrideWithValue(RoomActions(actions)),
        questionActionsProvider.overrideWithValue(QuestionActions(actions)),
        finalActionsProvider.overrideWithValue(FinalActions(actions)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RoomScreen(roomId: 'room-1', role: role),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('room screen renders question board for non-final phase', (
    tester,
  ) async {
    await _pump(
      tester,
      uid: 'host-1',
      room: _room(status: GameStatus.inGame, phase: GamePhase.boardSelect),
      players: <PlayerModel>[
        _player(uid: 'host-1', role: PlayerRole.host),
        _player(uid: 'p1', role: PlayerRole.player),
      ],
    );

    expect(find.byType(QuestionBoard), findsOneWidget);
    expect(find.byType(FinalRoundBoard), findsNothing);
    expect(find.byType(RoomTopBar), findsOneWidget);
    expect(find.byType(RoomSidePanel), findsOneWidget);
  });

  testWidgets('room screen renders final board for final phase', (
    tester,
  ) async {
    await _pump(
      tester,
      uid: 'host-1',
      room: _room(
        status: GameStatus.finalRound,
        phase: GamePhase.finalWagering,
      ),
      players: <PlayerModel>[
        _player(uid: 'host-1', role: PlayerRole.host),
        _player(uid: 'p1', role: PlayerRole.player),
      ],
    );

    expect(find.byType(FinalRoundBoard), findsOneWidget);
    expect(find.byType(QuestionBoard), findsNothing);
  });

  testWidgets('spectator can toggle clean view panels', (tester) async {
    await _pump(
      tester,
      uid: 'spec-1',
      room: _room(status: GameStatus.inGame, phase: GamePhase.boardSelect),
      role: PlayerRole.spectator,
      players: <PlayerModel>[
        _player(uid: 'host-1', role: PlayerRole.host),
        _player(uid: 'spec-1', role: PlayerRole.spectator),
      ],
    );

    expect(find.byType(RoomTopBar), findsNothing);
    expect(find.byType(RoomSidePanel), findsNothing);

    final toggle = find.byKey(const ValueKey('room_clean_view_toggle_button'));
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byType(RoomTopBar), findsOneWidget);
    expect(find.byType(RoomSidePanel), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byType(RoomTopBar), findsNothing);
    expect(find.byType(RoomSidePanel), findsNothing);
  });

  testWidgets('room screen dispose does not throw ref-after-dispose', (
    tester,
  ) async {
    await _pump(
      tester,
      uid: 'host-1',
      room: _room(status: GameStatus.inGame, phase: GamePhase.boardSelect),
      players: <PlayerModel>[_player(uid: 'host-1', role: PlayerRole.host)],
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
