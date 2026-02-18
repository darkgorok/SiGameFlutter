import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:si_game_flutter/features/game/game_models.dart';
import 'package:si_game_flutter/features/packs/local_pack.dart';

void main() {
  test('full pack flow: create/export/import with all question/media types', () {
    final questions = <LocalPackQuestion>[];
    var idx = 0;
    for (final type in QuestionType.values) {
      for (final media in QuestionMediaType.values) {
        idx += 1;
        final mediaUrl = media == QuestionMediaType.none
            ? ''
            : 'https://cdn.example.com/$idx.${_extensionFor(media)}';
        questions.add(
          LocalPackQuestion(
            theme: 'Theme-$idx',
            text: 'Question-$idx',
            answer: type == QuestionType.closestNumber ? '$idx' : 'Answer-$idx',
            cost: idx * 100,
            round: idx.isEven ? 2 : 1,
            type: type,
            mediaUrl: mediaUrl,
            mediaType: media,
            aliases: <String>['Alias-$idx'],
          ),
        );
      }
    }

    final pack = LocalPackDocument(
      name: 'Championship Pack',
      questions: questions,
    );

    final exported = pack.toJson();
    _validatePackJsonStructure(exported);

    final encoded = jsonEncode(exported);
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    final imported = LocalPackDocument.fromJson(decoded);

    expect(imported.name, 'Championship Pack');
    expect(
      imported.questions.length,
      QuestionType.values.length * QuestionMediaType.values.length,
    );

    for (var i = 0; i < imported.questions.length; i += 1) {
      final original = questions[i];
      final restored = imported.questions[i];
      expect(restored.theme, original.theme);
      expect(restored.text, original.text);
      expect(restored.answer, original.answer);
      expect(restored.cost, original.cost);
      expect(restored.round, original.round);
      expect(restored.type, original.type);
      expect(restored.mediaType, original.mediaType);
      expect(restored.mediaUrl, original.mediaUrl);
      expect(restored.aliases, original.aliases);
    }

    final reExported = imported.toJson();
    _validatePackJsonStructure(reExported);
    expect(reExported['name'], exported['name']);
    expect(
      (reExported['questions'] as List).length,
      QuestionType.values.length * QuestionMediaType.values.length,
    );
  });
}

String _extensionFor(QuestionMediaType mediaType) {
  switch (mediaType) {
    case QuestionMediaType.none:
      return 'txt';
    case QuestionMediaType.image:
      return 'png';
    case QuestionMediaType.audio:
      return 'mp3';
    case QuestionMediaType.video:
      return 'mp4';
  }
}

void _validatePackJsonStructure(Map<String, dynamic> json) {
  expect(json['version'], 1);
  expect(json['name'], isA<String>());
  expect((json['name'] as String).trim().isNotEmpty, isTrue);

  final questions = json['questions'];
  expect(questions, isA<List<dynamic>>());
  final list = questions as List<dynamic>;
  expect(list.isNotEmpty, isTrue);

  for (final item in list) {
    expect(item, isA<Map<dynamic, dynamic>>());
    final q = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);

    expect((q['theme'] as String?)?.trim().isNotEmpty ?? false, isTrue);
    expect((q['text'] as String?)?.trim().isNotEmpty ?? false, isTrue);
    expect((q['answer'] as String?)?.trim().isNotEmpty ?? false, isTrue);
    expect((q['cost'] as num?)?.toInt() ?? 0, greaterThan(0));
    expect((q['round'] as num?)?.toInt() ?? 0, greaterThan(0));

    final type = q['type'] as String?;
    expect(
      QuestionType.values.map((e) => e.value).contains(type),
      isTrue,
      reason: 'Unexpected question type: $type',
    );

    final mediaType = q['mediaType'] as String?;
    expect(
      QuestionMediaType.values.map((e) => e.value).contains(mediaType),
      isTrue,
      reason: 'Unexpected media type: $mediaType',
    );

    expect(q['aliases'], isA<List<dynamic>>());
  }
}
