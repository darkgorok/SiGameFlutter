import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:si_game_flutter/core/providers.dart';
import 'package:si_game_flutter/features/game/application/game_providers.dart';
import 'package:si_game_flutter/features/game/game_models.dart';
import 'package:si_game_flutter/features/game/presentation/widgets/room_side_panel.dart';
import 'package:si_game_flutter/l10n/app_localizations.dart';

RoomModel _room() {
  return RoomModel(
    id: 'room-1',
    name: 'Room',
    passwordProtected: false,
    hostUid: 'host-1',
    status: GameStatus.inGame,
    phase: GamePhase.boardSelect,
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

void main() {
  testWidgets('shows players summary for mixed roster', (tester) async {
    final players = <PlayerModel>[
      _player(uid: 'p1', role: PlayerRole.player),
      _player(uid: 's1', role: PlayerRole.spectator),
      _player(uid: 's2', role: PlayerRole.spectator),
    ];
    final events = <GameEventModel>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserUidProvider.overrideWith((ref) => 'host-1'),
          playersStreamProvider.overrideWith(
            (ref, roomId) => Stream.value(players),
          ),
          eventsStreamProvider.overrideWith(
            (ref, roomId) => Stream.value(events),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: RoomSidePanel(
                room: _room(),
                roomId: 'room-1',
                isHost: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Players: 3 | Active: 1 | Spectators: 2'), findsOneWidget);
  });
}
