import 'package:cloud_firestore/cloud_firestore.dart';

enum GameStatus {
  lobby('lobby', 'Лобби'),
  inGame('in_game', 'Игра'),
  paused('paused', 'Пауза'),
  finalRound('final_round', 'Финал'),
  completed('completed', 'Завершена');

  const GameStatus(this.value, this.label);
  final String value;
  final String label;

  static GameStatus fromValue(String? value) {
    return GameStatus.values.firstWhere(
      (v) => v.value == value,
      orElse: () => GameStatus.lobby,
    );
  }
}

enum GamePhase {
  lobby('lobby', 'Лобби'),
  boardSelect('board_select', 'Выбор вопроса'),
  questionReveal('question_reveal', 'Озвучивание вопроса'),
  catTargeting('cat_targeting', 'Кот в мешке: выбор игрока'),
  wagerBidding('wager_bidding', 'Аукцион: ставка'),
  answering('answering', 'Ответы'),
  answerReview('answer_review', 'Решение ведущего'),
  finalSetup('final_setup', 'Финал: настройка'),
  finalWagering('final_wagering', 'Финал: ставки'),
  finalAnswering('final_answering', 'Финал: ответы'),
  finalReveal('final_reveal', 'Финал: вскрытие'),
  gameOver('game_over', 'Игра завершена');

  const GamePhase(this.value, this.label);
  final String value;
  final String label;

  static GamePhase fromValue(String? value) {
    return GamePhase.values.firstWhere(
      (v) => v.value == value,
      orElse: () => GamePhase.lobby,
    );
  }
}

enum QuestionType {
  normal('normal', 'Обычный'),
  cat('cat_in_bag', 'Кот в мешке'),
  wager('wager', 'Вопрос-аукцион');

  const QuestionType(this.value, this.label);
  final String value;
  final String label;

  static QuestionType fromValue(String? value) {
    return QuestionType.values.firstWhere(
      (v) => v.value == value,
      orElse: () => QuestionType.normal,
    );
  }
}

class QuestionDraft {
  QuestionDraft({
    required this.theme,
    required this.text,
    required this.answer,
    required this.cost,
    required this.round,
    required this.type,
  });

  final String theme;
  final String text;
  final String answer;
  final int cost;
  final int round;
  final QuestionType type;
}

class RoomModel {
  RoomModel({
    required this.id,
    required this.name,
    required this.hostUid,
    required this.status,
    required this.phase,
    required this.currentRound,
    required this.chooserUid,
    required this.pausedByUid,
    required this.currentQuestionId,
    required this.activeQuestion,
    required this.timerDeadlineAtMs,
    required this.timerRemainingMs,
    required this.buzzQueue,
    required this.currentAttemptUid,
    required this.pendingAnswer,
    required this.targetedUid,
    required this.wagerValue,
    required this.finalTheme,
    required this.finalQuestion,
    required this.finalAnswer,
    required this.finalEligibleUids,
  });

  final String id;
  final String name;
  final String hostUid;
  final GameStatus status;
  final GamePhase phase;
  final int currentRound;
  final String? chooserUid;
  final String? pausedByUid;
  final String? currentQuestionId;
  final ActiveQuestion? activeQuestion;
  final int? timerDeadlineAtMs;
  final int? timerRemainingMs;
  final List<String> buzzQueue;
  final String? currentAttemptUid;
  final String? pendingAnswer;
  final String? targetedUid;
  final int? wagerValue;
  final String? finalTheme;
  final String? finalQuestion;
  final String? finalAnswer;
  final List<String> finalEligibleUids;

  factory RoomModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final activeData = data['activeQuestion'] as Map<String, dynamic>?;
    return RoomModel(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      hostUid: data['hostUid'] as String? ?? '',
      status: GameStatus.fromValue(data['status'] as String?),
      phase: GamePhase.fromValue(data['phase'] as String?),
      currentRound: (data['currentRound'] as num?)?.toInt() ?? 1,
      chooserUid: data['chooserUid'] as String?,
      pausedByUid: data['pausedByUid'] as String?,
      currentQuestionId: data['currentQuestionId'] as String?,
      activeQuestion: activeData == null
          ? null
          : ActiveQuestion.fromMap(activeData),
      timerDeadlineAtMs: (data['timerDeadlineAtMs'] as num?)?.toInt(),
      timerRemainingMs: (data['timerRemainingMs'] as num?)?.toInt(),
      buzzQueue: ((data['buzzQueue'] as List?) ?? []).cast<String>(),
      currentAttemptUid: data['currentAttemptUid'] as String?,
      pendingAnswer: data['pendingAnswer'] as String?,
      targetedUid: data['targetedUid'] as String?,
      wagerValue: (data['wagerValue'] as num?)?.toInt(),
      finalTheme: data['finalTheme'] as String?,
      finalQuestion: data['finalQuestion'] as String?,
      finalAnswer: data['finalAnswer'] as String?,
      finalEligibleUids: ((data['finalEligibleUids'] as List?) ?? [])
          .cast<String>(),
    );
  }
}

class ActiveQuestion {
  ActiveQuestion({
    required this.id,
    required this.theme,
    required this.text,
    required this.answer,
    required this.cost,
    required this.type,
  });

  final String id;
  final String theme;
  final String text;
  final String answer;
  final int cost;
  final QuestionType type;

  factory ActiveQuestion.fromMap(Map<String, dynamic> data) {
    return ActiveQuestion(
      id: data['id'] as String? ?? '',
      theme: data['theme'] as String? ?? 'Тема',
      text: data['text'] as String? ?? '',
      answer: data['answer'] as String? ?? '',
      cost: (data['cost'] as num?)?.toInt() ?? 100,
      type: QuestionType.fromValue(data['type'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'theme': theme,
      'text': text,
      'answer': answer,
      'cost': cost,
      'type': type.value,
    };
  }
}

class QuestionModel {
  QuestionModel({
    required this.id,
    required this.theme,
    required this.text,
    required this.answer,
    required this.cost,
    required this.round,
    required this.used,
    required this.type,
  });

  final String id;
  final String theme;
  final String text;
  final String answer;
  final int cost;
  final int round;
  final bool used;
  final QuestionType type;

  factory QuestionModel.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return QuestionModel(
      id: doc.id,
      theme: data['theme'] as String? ?? 'Без темы',
      text: data['text'] as String? ?? '',
      answer: data['answer'] as String? ?? '',
      cost: (data['cost'] as num?)?.toInt() ?? 100,
      round: (data['round'] as num?)?.toInt() ?? 1,
      used: data['used'] as bool? ?? false,
      type: QuestionType.fromValue(data['type'] as String?),
    );
  }
}

class PlayerModel {
  PlayerModel({
    required this.uid,
    required this.nickname,
    required this.score,
    required this.connected,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.buzzCount,
  });

  final String uid;
  final String nickname;
  final int score;
  final bool connected;
  final int correctAnswers;
  final int wrongAnswers;
  final int buzzCount;

  factory PlayerModel.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return PlayerModel(
      uid: doc.id,
      nickname: data['nickname'] as String? ?? doc.id,
      score: (data['score'] as num?)?.toInt() ?? 0,
      connected: data['connected'] as bool? ?? false,
      correctAnswers: (data['correctAnswers'] as num?)?.toInt() ?? 0,
      wrongAnswers: (data['wrongAnswers'] as num?)?.toInt() ?? 0,
      buzzCount: (data['buzzCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class GameEventModel {
  GameEventModel({
    required this.id,
    required this.type,
    required this.message,
    required this.actorUid,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String message;
  final String actorUid;
  final DateTime? createdAt;

  factory GameEventModel.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return GameEventModel(
      id: doc.id,
      type: data['type'] as String? ?? 'system',
      message: data['message'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
