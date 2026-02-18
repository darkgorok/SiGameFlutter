import 'package:cloud_firestore/cloud_firestore.dart';

import '../game_models.dart';
import 'game_dtos.dart';

extension RoomDtoToDomain on RoomDto {
  RoomModel toDomain() {
    final activeData = data['activeQuestion'] as Map<String, dynamic>?;
    return RoomModel(
      id: id,
      name: data['name'] as String? ?? id,
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

  bool _readPasswordProtected(Map<String, dynamic> data) {
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

extension QuestionDtoToDomain on QuestionDto {
  QuestionModel toDomain() {
    return QuestionModel(
      id: id,
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

extension PlayerDtoToDomain on PlayerDto {
  PlayerModel toDomain() {
    return PlayerModel(
      uid: id,
      nickname: data['nickname'] as String? ?? id,
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

extension GameEventDtoToDomain on GameEventDto {
  GameEventModel toDomain() {
    final createdRaw = data['createdAt'];
    DateTime? createdAt;
    if (createdRaw is Timestamp) {
      createdAt = createdRaw.toDate();
    } else if (createdRaw is DateTime) {
      createdAt = createdRaw;
    }
    return GameEventModel(
      id: id,
      type: data['type'] as String? ?? 'system',
      message: data['message'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      createdAt: createdAt,
    );
  }
}
