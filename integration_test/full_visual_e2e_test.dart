import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:si_game_flutter/app/app_entry.dart';
import 'package:si_game_flutter/features/game/game_models.dart';
import 'package:si_game_flutter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('visual full pack + full game flow (all question/media types)', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    await _completeProfileSetupIfNeeded(tester);
    await _openPackEditorAndBuildPack(tester);

    final roomId = await _createRoomWithAllQuestionTypesAndMedia();
    await _openRoomFromRoomsList(tester, roomId);
    await _playFullGameFlow(tester, roomId);

    final room = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .get();
    expect(room.exists, isTrue);
    expect(room.data()?['status'], 'completed');
    expect(room.data()?['phase'], 'game_over');
  });
}

Future<void> _completeProfileSetupIfNeeded(WidgetTester tester) async {
  if (find.byType(FirebaseSetupScreen).evaluate().isNotEmpty) {
    throw TestFailure(
      'Firebase is not configured for web build. '
      'Run with --dart-define FIREBASE_* values.',
    );
  }

  final homeButton = find.byKey(const ValueKey('home_pack_editor_button'));
  for (var attempt = 0; attempt < 8; attempt += 1) {
    if (homeButton.evaluate().isNotEmpty) {
      return;
    }

    final nicknameField = find.byKey(const ValueKey('profile_nickname_field'));
    final continueButton = find.byKey(const ValueKey('profile_continue_button'));
    if (nicknameField.evaluate().isNotEmpty && continueButton.evaluate().isNotEmpty) {
      await tester.enterText(nicknameField, 'E2E Visual User');
      await _slowStep(tester);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      await _slowStep(tester, seconds: 1);
    } else {
      await tester.pump(const Duration(seconds: 2));
    }
  }

  await _pumpUntilVisible(
    tester,
    homeButton,
    timeout: const Duration(seconds: 90),
  );
}

Future<void> _openPackEditorAndBuildPack(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('home_pack_editor_button')));
  await tester.pumpAndSettle();
  await _slowStep(tester);

  await tester.tap(
    find.byKey(const ValueKey('home_pack_editor_create_button')),
  );
  await tester.pumpAndSettle();
  await _slowStep(tester, seconds: 1);

  await tester.enterText(
    find.byKey(const ValueKey('pack_editor_pack_name_field')),
    'Visual E2E Full Pack',
  );
  await _slowStep(tester);

  await tester.tap(find.byKey(const ValueKey('pack_editor_add_theme_button')));
  await tester.pumpAndSettle();
  await _slowStep(tester);

  final scenarios = <_PackScenario>[
    _PackScenario(
      text: 'Question 1 normal image',
      answer: 'A1',
      cost: 100,
      type: QuestionType.normal,
      mediaType: QuestionMediaType.image,
      mediaUrl: 'https://cdn.example.com/q1.png',
    ),
    _PackScenario(
      text: 'Question 2 cat audio',
      answer: 'A2',
      cost: 200,
      type: QuestionType.cat,
      mediaType: QuestionMediaType.audio,
      mediaUrl: 'https://cdn.example.com/q2.mp3',
    ),
    _PackScenario(
      text: 'Question 3 wager video',
      answer: 'A3',
      cost: 300,
      type: QuestionType.wager,
      mediaType: QuestionMediaType.video,
      mediaUrl: 'https://cdn.example.com/q3.mp4',
    ),
    _PackScenario(
      text: 'Question 4 closest none',
      answer: '42',
      cost: 400,
      type: QuestionType.closestNumber,
      mediaType: QuestionMediaType.none,
      mediaUrl: '',
    ),
  ];

  for (final scenario in scenarios) {
    await tester.tap(
      find.byKey(const ValueKey('pack_editor_add_question_button')),
    );
    await tester.pumpAndSettle();
    await _slowStep(tester);

    await tester.enterText(
      find.byKey(const ValueKey('pack_editor_question_field')),
      scenario.text,
    );
    await _slowStep(tester);
    await tester.enterText(
      find.byKey(const ValueKey('pack_editor_answer_field')),
      scenario.answer,
    );
    await _slowStep(tester);
    await tester.enterText(
      find.byKey(const ValueKey('pack_editor_cost_field')),
      scenario.cost.toString(),
    );
    await _slowStep(tester);
    await _selectQuestionTypeInPackEditor(tester, scenario.type);
    await _slowStep(tester);
    await _selectMediaTypeInPackEditor(tester, scenario.mediaType);
    await _slowStep(tester);
    await tester.enterText(
      find.byKey(const ValueKey('pack_editor_media_url_field')),
      scenario.mediaUrl,
    );
    await _slowStep(tester);
    await tester.enterText(
      find.byKey(const ValueKey('pack_editor_aliases_field')),
      'alias-${scenario.cost}',
    );
    await _slowStep(tester, seconds: 1);
  }

  await _pumpUntilVisible(
    tester,
    find.textContaining('Question 1 normal image'),
  );
  await tester.tap(find.textContaining('Question 1 normal image').first);
  await tester.pumpAndSettle();
  await _slowStep(tester);
  await tester.enterText(
    find.byKey(const ValueKey('pack_editor_answer_field')),
    'A1 edited',
  );
  await _slowStep(tester, seconds: 1);

  await tester.pageBack();
  await tester.pumpAndSettle();
  await _slowStep(tester);
}

Future<String> _createRoomWithAllQuestionTypesAndMedia() async {
  final callable = FirebaseFunctions.instance.httpsCallable('gameCommand');
  final roomName = 'VisualE2E-${DateTime.now().millisecondsSinceEpoch}';

  final createResponse = await callable.call(<String, dynamic>{
    'command': 'create_room',
    'data': <String, dynamic>{'roomName': roomName},
  });
  final roomId = (createResponse.data as Map)['roomId'] as String;

  await callable.call(<String, dynamic>{
    'command': 'add_questions_bulk',
    'roomId': roomId,
    'data': <String, dynamic>{
      'questions': <Map<String, dynamic>>[
        <String, dynamic>{
          'theme': 'Visual Theme',
          'text': 'Normal image question',
          'answer': 'normal',
          'cost': 100,
          'round': 1,
          'type': 'normal',
          'mediaUrl': 'https://cdn.example.com/normal.png',
          'mediaType': 'image',
          'aliases': <String>['normal'],
        },
        <String, dynamic>{
          'theme': 'Visual Theme',
          'text': 'Cat audio question',
          'answer': 'cat',
          'cost': 200,
          'round': 1,
          'type': 'cat_in_bag',
          'mediaUrl': 'https://cdn.example.com/cat.mp3',
          'mediaType': 'audio',
          'aliases': <String>['cat'],
        },
        <String, dynamic>{
          'theme': 'Visual Theme',
          'text': 'Wager video question',
          'answer': 'wager',
          'cost': 300,
          'round': 1,
          'type': 'wager',
          'mediaUrl': 'https://cdn.example.com/wager.mp4',
          'mediaType': 'video',
          'aliases': <String>['wager'],
        },
        <String, dynamic>{
          'theme': 'Visual Theme',
          'text': 'Closest number question',
          'answer': '0',
          'cost': 400,
          'round': 1,
          'type': 'closest_number',
          'mediaUrl': '',
          'mediaType': 'none',
          'aliases': <String>[],
        },
      ],
    },
  });
  return roomId;
}

Future<void> _openRoomFromRoomsList(WidgetTester tester, String roomId) async {
  await _pumpUntilVisible(
    tester,
    find.byKey(const ValueKey('home_find_room_button')),
  );
  await tester.tap(find.byKey(const ValueKey('home_find_room_button')));
  await tester.pumpAndSettle();
  await _slowStep(tester, seconds: 1);

  await _pumpUntilVisible(
    tester,
    find.byKey(ValueKey('rooms_join_player_$roomId')),
    timeout: const Duration(seconds: 40),
  );
  await tester.tap(find.byKey(ValueKey('rooms_join_player_$roomId')));
  await tester.pumpAndSettle();
  await _slowStep(tester, seconds: 1);
}

Future<void> _playFullGameFlow(WidgetTester tester, String roomId) async {
  await _tapKey(tester, 'room_start_game_button');

  await _tapQuestionCell(tester, '_100_normal_image');
  await _tapKey(tester, 'room_open_buzzing_button');
  await _tapKey(tester, 'room_buzz_button');
  await _tapKey(tester, 'room_submit_voice_answer_button');
  await _tapKey(tester, 'room_judge_correct_button');

  await _tapQuestionCell(tester, '_200_cat_in_bag_audio');
  await _pumpUntilVisible(
    tester,
    find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('room_cat_target_'),
    ),
  );
  await tester.tap(
    find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('room_cat_target_'),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await _slowStep(tester);
  await _tapKey(tester, 'room_submit_voice_answer_button');
  await _tapKey(tester, 'room_judge_correct_button');

  await _tapQuestionCell(tester, '_300_wager_video');
  await tester.enterText(find.byKey(const ValueKey('room_wager_field')), '100');
  await _slowStep(tester);
  await _tapKey(tester, 'room_confirm_wager_button');
  await _tapKey(tester, 'room_submit_voice_answer_button');
  await _tapKey(tester, 'room_judge_correct_button');

  await _tapQuestionCell(tester, '_400_closest_number_none');
  await tester.enterText(
    find.byKey(const ValueKey('room_numeric_answer_field')),
    '0',
  );
  await _slowStep(tester);
  await _tapKey(tester, 'room_submit_numeric_answer_button');

  await _waitUntilRoomPhase(
    roomId,
    'final_setup',
    const Duration(seconds: 35),
  );

  await tester.enterText(
    find.byKey(const ValueKey('final_theme_field')),
    'Final Theme',
  );
  await _slowStep(tester);
  await tester.enterText(
    find.byKey(const ValueKey('final_question_field')),
    'Final visual question?',
  );
  await _slowStep(tester);
  await tester.enterText(
    find.byKey(const ValueKey('final_answer_field')),
    'Final',
  );
  await _slowStep(tester);
  await _tapKey(tester, 'final_save_question_button');
  await _tapKey(tester, 'final_open_wagers_button');

  await tester.enterText(
    find.byKey(const ValueKey('final_wager_field')),
    '300',
  );
  await _slowStep(tester);
  await _tapKey(tester, 'final_place_wager_button');
  await _tapKey(tester, 'final_open_answers_button');

  await _pumpUntilVisible(
    tester,
    find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'final_result_correct_',
          ),
    ),
  );
  await tester.tap(
    find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'final_result_correct_',
              ),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await _slowStep(tester);

  await _tapKey(tester, 'final_reveal_button');
  await _waitUntilRoomPhase(roomId, 'game_over', const Duration(seconds: 20));
}

Future<void> _tapQuestionCell(WidgetTester tester, String keySuffix) async {
  final finder = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.contains(keySuffix),
  );
  await _pumpUntilVisible(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
  await _slowStep(tester, seconds: 1);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await _pumpUntilVisible(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await _slowStep(tester, seconds: 1);
}

Future<void> _selectQuestionTypeInPackEditor(
  WidgetTester tester,
  QuestionType type,
) async {
  await tester.tap(find.byKey(const ValueKey('pack_editor_type_dropdown')));
  await tester.pumpAndSettle();
  final option = find.byWidgetPredicate(
    (w) => w is DropdownMenuItem<QuestionType> && w.value == type,
  );
  await _pumpUntilVisible(tester, option);
  await tester.tap(option.last);
  await tester.pumpAndSettle();
}

Future<void> _selectMediaTypeInPackEditor(
  WidgetTester tester,
  QuestionMediaType mediaType,
) async {
  await tester.tap(
    find.byKey(const ValueKey('pack_editor_media_type_dropdown')),
  );
  await tester.pumpAndSettle();
  final option = find.byWidgetPredicate(
    (w) => w is DropdownMenuItem<QuestionMediaType> && w.value == mediaType,
  );
  await _pumpUntilVisible(tester, option);
  await tester.tap(option.last);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final started = DateTime.now();
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().difference(started) > timeout) {
      throw TestFailure('Timeout waiting for finder: $finder');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _waitUntilRoomPhase(
  String roomId,
  String phase,
  Duration timeout,
) async {
  final started = DateTime.now();
  while (true) {
    final snap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .get();
    if (snap.data()?['phase'] == phase) {
      return;
    }
    if (DateTime.now().difference(started) > timeout) {
      throw TestFailure('Timeout waiting room phase=$phase');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

Future<void> _slowStep(WidgetTester tester, {int seconds = 1}) async {
  await tester.pump(Duration(seconds: seconds));
}

class _PackScenario {
  const _PackScenario({
    required this.text,
    required this.answer,
    required this.cost,
    required this.type,
    required this.mediaType,
    required this.mediaUrl,
  });

  final String text;
  final String answer;
  final int cost;
  final QuestionType type;
  final QuestionMediaType mediaType;
  final String mediaUrl;
}
