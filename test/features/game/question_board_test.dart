import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:si_game_flutter/core/providers.dart';
import 'package:si_game_flutter/features/game/application/game_providers.dart';
import 'package:si_game_flutter/features/game/game_models.dart';
import 'package:si_game_flutter/features/game/presentation/widgets/question_flow_widgets.dart';
import 'package:si_game_flutter/l10n/app_localizations.dart';

RoomModel _room({
  required GameStatus status,
  required GamePhase phase,
  required String hostUid,
  String? chooserUid,
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

QuestionModel _question({required bool used}) {
  return QuestionModel(
    id: 'q1',
    theme: 'Theme',
    text: 'Question',
    answer: 'Answer',
    cost: 100,
    round: 1,
    used: used,
    type: QuestionType.normal,
    mediaUrl: '',
    mediaType: QuestionMediaType.none,
    aliases: const <String>[],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required RoomModel room,
  required String uid,
  required List<QuestionModel> questions,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserUidProvider.overrideWith((ref) => uid),
        questionsStreamProvider.overrideWith(
          (ref, roomId) => Stream.value(questions),
        ),
        playersStreamProvider.overrideWith(
          (ref, roomId) => Stream.value(const <PlayerModel>[]),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 900,
            child: QuestionBoard(
              room: room,
              roomId: 'room-1',
              myRole: PlayerRole.player,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _pickCellKey() =>
    find.byKey(const ValueKey('room_pick_question_q1_100_normal_none'));

void main() {
  testWidgets('chooser can pick open question in board_select', (tester) async {
    final room = _room(
      status: GameStatus.inGame,
      phase: GamePhase.boardSelect,
      hostUid: 'host-1',
      chooserUid: 'p1',
    );
    await _pump(
      tester,
      room: room,
      uid: 'p1',
      questions: <QuestionModel>[_question(used: false)],
    );

    final cell = tester.widget<InkWell>(_pickCellKey());
    expect(cell.onTap, isNotNull);
  });

  testWidgets('non-host non-chooser cannot pick question', (tester) async {
    final room = _room(
      status: GameStatus.inGame,
      phase: GamePhase.boardSelect,
      hostUid: 'host-1',
      chooserUid: 'p1',
    );
    await _pump(
      tester,
      room: room,
      uid: 'p2',
      questions: <QuestionModel>[_question(used: false)],
    );

    final cell = tester.widget<InkWell>(_pickCellKey());
    expect(cell.onTap, isNull);
  });

  testWidgets('host cannot pick while paused', (tester) async {
    final room = _room(
      status: GameStatus.paused,
      phase: GamePhase.boardSelect,
      hostUid: 'host-1',
      chooserUid: 'p1',
    );
    await _pump(
      tester,
      room: room,
      uid: 'host-1',
      questions: <QuestionModel>[_question(used: false)],
    );

    final cell = tester.widget<InkWell>(_pickCellKey());
    expect(cell.onTap, isNull);
  });

  testWidgets('used question is not pickable even for chooser', (tester) async {
    final room = _room(
      status: GameStatus.inGame,
      phase: GamePhase.boardSelect,
      hostUid: 'host-1',
      chooserUid: 'p1',
    );
    await _pump(
      tester,
      room: room,
      uid: 'p1',
      questions: <QuestionModel>[_question(used: true)],
    );

    final cell = tester.widget<InkWell>(_pickCellKey());
    expect(cell.onTap, isNull);
  });
}
