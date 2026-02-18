import 'package:cloud_firestore/cloud_firestore.dart';

enum GameStatus {
  lobby('lobby', 'Lobby'),
  inGame('in_game', 'In game'),
  paused('paused', 'Paused'),
  finalRound('final_round', 'Final'),
  completed('completed', 'Completed');

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
  lobby('lobby', 'Lobby'),
  boardSelect('board_select', 'Question selection'),
  questionReveal('question_reveal', 'Question reveal'),
  catTargeting('cat_targeting', 'Cat in a bag: choose player'),
  wagerBidding('wager_bidding', 'Auction: wager'),
  answering('answering', 'Answering'),
  answerReview('answer_review', 'Host decision'),
  finalSetup('final_setup', 'Final: setup'),
  finalWagering('final_wagering', 'Final: wagers'),
  finalAnswering('final_answering', 'Final: voice answers'),
  finalReveal('final_reveal', 'Final: reveal'),
  gameOver('game_over', 'Game over');

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
  normal('normal', 'Normal'),
  cat('cat_in_bag', 'Cat in a bag'),
  wager('wager', 'Auction question'),
  closestNumber('closest_number', 'Closest number');

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

enum QuestionMediaType {
  none('none', 'No media'),
  image('image', 'Image'),
  audio('audio', 'Audio'),
  video('video', 'Video');

  const QuestionMediaType(this.value, this.label);
  final String value;
  final String label;

  static QuestionMediaType fromValue(String? value) {
    return QuestionMediaType.values.firstWhere(
      (v) => v.value == value,
      orElse: () => QuestionMediaType.none,
    );
  }
}

enum PlayerRole {
  host('host', 'Host'),
  player('player', 'Player'),
  spectator('spectator', 'Spectator'),
  editor('editor', 'Editor');

  const PlayerRole(this.value, this.label);
  final String value;
  final String label;

  static PlayerRole fromValue(String? value) {
    return PlayerRole.values.firstWhere(
      (v) => v.value == value,
      orElse: () => PlayerRole.player,
    );
  }
}

enum FinalResult {
  pending('pending', 'Pending'),
  correct('correct', 'Correct'),
  wrong('wrong', 'Wrong'),
  noAnswer('no_answer', 'No answer');

  const FinalResult(this.value, this.label);
  final String value;
  final String label;

  static FinalResult fromValue(String? value) {
    return FinalResult.values.firstWhere(
      (v) => v.value == value,
      orElse: () => FinalResult.pending,
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
}

class RoomModel {
  RoomModel({
    required this.id,
    required this.name,
    required this.passwordProtected,
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
  final bool passwordProtected;
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
      passwordProtected: _readPasswordProtected(data),
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

  static bool _readPasswordProtected(Map<String, dynamic> data) {
    final direct = data['passwordProtected'];
    if (direct is bool) {
      return direct;
    }
    final hasPassword = data['hasPassword'];
    if (hasPassword is bool) {
      return hasPassword;
    }
    final required = data['passwordRequired'];
    if (required is bool) {
      return required;
    }
    return false;
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
    required this.mediaUrl,
    required this.mediaType,
    required this.aliases,
  });

  final String id;
  final String theme;
  final String text;
  final String answer;
  final int cost;
  final QuestionType type;
  final String mediaUrl;
  final QuestionMediaType mediaType;
  final List<String> aliases;

  factory ActiveQuestion.fromMap(Map<String, dynamic> data) {
    return ActiveQuestion(
      id: data['id'] as String? ?? '',
      theme: data['theme'] as String? ?? 'Theme',
      text: data['text'] as String? ?? '',
      answer: data['answer'] as String? ?? '',
      cost: (data['cost'] as num?)?.toInt() ?? 100,
      type: QuestionType.fromValue(data['type'] as String?),
      mediaUrl: data['mediaUrl'] as String? ?? '',
      mediaType: QuestionMediaType.fromValue(data['mediaType'] as String?),
      aliases: ((data['aliases'] as List?) ?? []).cast<String>(),
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
      'mediaUrl': mediaUrl,
      'mediaType': mediaType.value,
      'aliases': aliases,
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
    required this.mediaUrl,
    required this.mediaType,
    required this.aliases,
  });

  final String id;
  final String theme;
  final String text;
  final String answer;
  final int cost;
  final int round;
  final bool used;
  final QuestionType type;
  final String mediaUrl;
  final QuestionMediaType mediaType;
  final List<String> aliases;

  factory QuestionModel.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return QuestionModel(
      id: doc.id,
      theme: data['theme'] as String? ?? 'No theme',
      text: data['text'] as String? ?? '',
      answer: data['answer'] as String? ?? '',
      cost: (data['cost'] as num?)?.toInt() ?? 100,
      round: (data['round'] as num?)?.toInt() ?? 1,
      used: data['used'] as bool? ?? false,
      type: QuestionType.fromValue(data['type'] as String?),
      mediaUrl: data['mediaUrl'] as String? ?? '',
      mediaType: QuestionMediaType.fromValue(data['mediaType'] as String?),
      aliases: ((data['aliases'] as List?) ?? []).cast<String>(),
    );
  }
}

class PlayerModel {
  PlayerModel({
    required this.uid,
    required this.nickname,
    required this.avatarUrl,
    required this.role,
    required this.score,
    required this.connected,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.buzzCount,
    required this.finalWager,
    required this.finalResult,
  });

  final String uid;
  final String nickname;
  final String avatarUrl;
  final PlayerRole role;
  final int score;
  final bool connected;
  final int correctAnswers;
  final int wrongAnswers;
  final int buzzCount;
  final int finalWager;
  final FinalResult finalResult;

  factory PlayerModel.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return PlayerModel(
      uid: doc.id,
      nickname: data['nickname'] as String? ?? doc.id,
      avatarUrl: data['avatarUrl'] as String? ?? '',
      role: PlayerRole.fromValue(data['role'] as String?),
      score: (data['score'] as num?)?.toInt() ?? 0,
      connected: data['connected'] as bool? ?? false,
      correctAnswers: (data['correctAnswers'] as num?)?.toInt() ?? 0,
      wrongAnswers: (data['wrongAnswers'] as num?)?.toInt() ?? 0,
      buzzCount: (data['buzzCount'] as num?)?.toInt() ?? 0,
      finalWager: (data['finalWager'] as num?)?.toInt() ?? 0,
      finalResult: FinalResult.fromValue(data['finalResult'] as String?),
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

class PackSummary {
  PackSummary({
    required this.id,
    required this.name,
    required this.version,
    required this.questionCount,
  });

  final String id;
  final String name;
  final int version;
  final int questionCount;
}

class LeaderboardEntry {
  LeaderboardEntry({
    required this.uid,
    required this.nickname,
    required this.games,
    required this.wins,
    required this.totalScore,
  });

  final String uid;
  final String nickname;
  final int games;
  final int wins;
  final int totalScore;
}
