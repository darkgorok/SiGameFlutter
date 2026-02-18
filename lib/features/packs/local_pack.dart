import '../game/game_models.dart';

class LocalPackQuestion {
  LocalPackQuestion({
    required this.theme,
    required this.text,
    required this.answer,
    required this.cost,
    required this.round,
    required this.type,
    required this.mediaUrl,
    required this.mediaType,
    required this.aliases,
  });

  final String theme;
  final String text;
  final String answer;
  final int cost;
  final int round;
  final QuestionType type;
  final String mediaUrl;
  final QuestionMediaType mediaType;
  final List<String> aliases;

  factory LocalPackQuestion.fromJson(Map<String, dynamic> map) {
    return LocalPackQuestion(
      theme: (map['theme'] ?? '').toString().trim(),
      text: (map['text'] ?? '').toString().trim(),
      answer: (map['answer'] ?? '').toString().trim(),
      cost: (map['cost'] as num?)?.toInt() ?? 100,
      round: (map['round'] as num?)?.toInt() ?? 1,
      type: QuestionType.fromValue(map['type'] as String?),
      mediaUrl: (map['mediaUrl'] ?? '').toString().trim(),
      mediaType: QuestionMediaType.fromValue(map['mediaType'] as String?),
      aliases: ((map['aliases'] as List?) ?? const [])
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'text': text,
      'answer': answer,
      'cost': cost,
      'round': round,
      'type': type.value,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType.value,
      'aliases': aliases,
    };
  }

  QuestionDraft toDraft() {
    return QuestionDraft(
      theme: theme,
      text: text,
      answer: answer,
      cost: cost,
      round: round,
      type: type,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      aliases: aliases,
    );
  }
}

class LocalPackDocument {
  LocalPackDocument({required this.name, required this.questions});

  final String name;
  final List<LocalPackQuestion> questions;

  factory LocalPackDocument.fromJson(dynamic raw) {
    if (raw is List) {
      final questions = raw
          .whereType<Map>()
          .map((e) => LocalPackQuestion.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return LocalPackDocument(name: 'Pack', questions: questions);
    }
    if (raw is! Map) {
      throw FormatException('Invalid pack JSON');
    }
    final map = Map<String, dynamic>.from(raw);
    final list = (map['questions'] as List?) ?? const [];
    final questions = list
        .whereType<Map>()
        .map((e) => LocalPackQuestion.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return LocalPackDocument(
      name: (map['name'] ?? '').toString().trim().isEmpty
          ? 'Pack'
          : map['name'].toString().trim(),
      questions: questions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'name': name,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}
