import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/errors/app_exception.dart';
import '../../core/shared_prefs_cache.dart';
import 'data/game_commands.dart';
import 'game_models.dart';

class GameService {
  GameService({
    required this.firestore,
    required this.auth,
    required this.functions,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final FirebaseFunctions functions;
  static const _roomsQueryLimit = 100;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRooms() {
    return watchRoomsLimited(limit: _roomsQueryLimit);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRoomsLimited({
    required int limit,
  }) {
    return firestore
        .collection('rooms')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchRoomsPage({
    required int limit,
    int? startAfterCreatedAtMs,
  }) async {
    var query = firestore
        .collection('rooms')
        .orderBy('createdAt', descending: true)
        .limit(limit + 1);
    if (startAfterCreatedAtMs != null) {
      query = query.startAfter([
        Timestamp.fromMillisecondsSinceEpoch(startAfterCreatedAtMs),
      ]);
    }
    return query.get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String roomId) {
    return firestore.collection('rooms').doc(roomId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPlayers(String roomId) {
    return firestore
        .collection('rooms')
        .doc(roomId)
        .collection('players')
        .orderBy('score', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchQuestions(String roomId) {
    return firestore
        .collection('rooms')
        .doc(roomId)
        .collection('questions')
        .orderBy('round')
        .orderBy('theme')
        .orderBy('cost')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchEvents(String roomId) {
    return firestore
        .collection('rooms')
        .doc(roomId)
        .collection('events')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> upsertProfile({
    required String uid,
    required String nickname,
    required String avatarUrl,
  }) async {
    await _callCommand(
      command: GameCommand.upsertProfile,
      data: {'uid': uid, 'nickname': nickname, 'avatarUrl': avatarUrl},
    );
  }

  Future<String> createRoom({
    required String roomName,
    String? password,
  }) async {
    final normalizedPassword = password?.trim() ?? '';
    final data = await _callCommand(
      command: GameCommand.createRoom,
      data: {
        'roomName': roomName,
        if (normalizedPassword.isNotEmpty) 'password': normalizedPassword,
      },
    );
    final roomId = data['roomId'] as String?;
    if (roomId == null || roomId.isEmpty) {
      throw const AppException(
        message: 'Server did not return roomId',
        code: 'invalid_response',
      );
    }
    await _storeLastRoom(roomId, role: PlayerRole.host);
    return roomId;
  }

  Future<void> joinRoom(
    String roomId, {
    PlayerRole role = PlayerRole.player,
    String? password,
  }) async {
    final normalizedPassword = password?.trim() ?? '';
    await _callCommand(
      command: GameCommand.joinRoom,
      roomId: roomId,
      data: {
        'role': role.value,
        if (normalizedPassword.isNotEmpty) 'password': normalizedPassword,
      },
    );
    await _storeLastRoom(roomId, role: role);
  }

  Future<void> markDisconnected(String roomId) async {
    await _callCommand(command: GameCommand.markDisconnected, roomId: roomId);
  }

  Future<void> addQuestion({
    required String roomId,
    required QuestionDraft draft,
  }) async {
    await _callCommand(
      command: GameCommand.addQuestion,
      roomId: roomId,
      data: {
        'theme': draft.theme,
        'text': draft.text,
        'answer': draft.answer,
        'cost': draft.cost,
        'round': draft.round,
        'type': draft.type.value,
        'mediaUrl': draft.mediaUrl,
        'mediaType': draft.mediaType.value,
        'aliases': draft.aliases,
      },
    );
  }

  Future<void> setPlayerRole({
    required String roomId,
    required String targetUid,
    required PlayerRole role,
  }) async {
    await _callCommand(
      command: GameCommand.setPlayerRole,
      roomId: roomId,
      data: {'targetUid': targetUid, 'role': role.value},
    );
  }

  Future<void> kickPlayer({
    required String roomId,
    required String targetUid,
  }) async {
    await _callCommand(
      command: GameCommand.kickPlayer,
      roomId: roomId,
      data: {'targetUid': targetUid},
    );
  }

  Future<void> banPlayer({
    required String roomId,
    required String targetUid,
    String reason = '',
  }) async {
    await _callCommand(
      command: GameCommand.banPlayer,
      roomId: roomId,
      data: {'targetUid': targetUid, 'reason': reason},
    );
  }

  Future<void> unbanPlayer({
    required String roomId,
    required String targetUid,
  }) async {
    await _callCommand(
      command: GameCommand.unbanPlayer,
      roomId: roomId,
      data: {'targetUid': targetUid},
    );
  }

  Future<PackSummary> savePack({
    required String roomId,
    required String name,
  }) async {
    final data = await _callCommand(
      command: GameCommand.savePack,
      roomId: roomId,
      data: {'name': name},
    );
    return PackSummary(
      id: data['packId'] as String? ?? '',
      name: name,
      version: (data['version'] as num?)?.toInt() ?? 1,
      questionCount: 0,
    );
  }

  Future<List<PackSummary>> listPacks() async {
    final data = await _callCommand(command: GameCommand.listPacks);
    final list = (data['packs'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map(
          (item) => PackSummary(
            id: item['id'] as String? ?? '',
            name: item['name'] as String? ?? 'Pack',
            version: (item['version'] as num?)?.toInt() ?? 1,
            questionCount: (item['questionCount'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  Future<void> applyPack({
    required String roomId,
    required String packId,
  }) async {
    await _callCommand(
      command: GameCommand.applyPack,
      roomId: roomId,
      data: {'packId': packId},
    );
  }

  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final data = await _callCommand(command: GameCommand.getLeaderboard);
    final list = (data['leaderboard'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map(
          (item) => LeaderboardEntry(
            uid: item['uid'] as String? ?? '',
            nickname: item['nickname'] as String? ?? 'Player',
            games: (item['games'] as num?)?.toInt() ?? 0,
            wins: (item['wins'] as num?)?.toInt() ?? 0,
            totalScore: (item['totalScore'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  Future<void> startGame(String roomId) async {
    await _callCommand(command: GameCommand.startGame, roomId: roomId);
  }

  Future<void> advanceToRound2(String roomId) async {
    await _callCommand(command: GameCommand.advanceRound2, roomId: roomId);
  }

  Future<void> startFinalRound(String roomId) async {
    await _callCommand(command: GameCommand.startFinalRound, roomId: roomId);
  }

  Future<void> setFinalQuestion({
    required String roomId,
    required String theme,
    required String question,
    required String answer,
  }) async {
    await _callCommand(
      command: GameCommand.setFinalQuestion,
      roomId: roomId,
      data: {'theme': theme, 'question': question, 'answer': answer},
    );
  }

  Future<void> openFinalWagers(String roomId) async {
    await _callCommand(command: GameCommand.openFinalWagers, roomId: roomId);
  }

  Future<void> openFinalAnswers(String roomId) async {
    await _callCommand(command: GameCommand.openFinalAnswers, roomId: roomId);
  }

  Future<void> submitFinalWager({
    required String roomId,
    required int wager,
  }) async {
    await _callCommand(
      command: GameCommand.submitFinalWager,
      roomId: roomId,
      data: {'wager': wager},
    );
  }

  Future<void> setFinalPlayerResult({
    required String roomId,
    required String targetUid,
    required FinalResult result,
  }) async {
    await _callCommand(
      command: GameCommand.setFinalPlayerResult,
      roomId: roomId,
      data: {'targetUid': targetUid, 'result': result.value},
    );
  }

  Future<void> revealFinal(String roomId) async {
    await _callCommand(command: GameCommand.revealFinal, roomId: roomId);
  }

  Future<void> pickQuestion({
    required String roomId,
    required String questionId,
  }) async {
    await _callCommand(
      command: GameCommand.pickQuestion,
      roomId: roomId,
      data: {'questionId': questionId},
    );
  }

  Future<void> openBuzzing(String roomId) async {
    await _callCommand(command: GameCommand.openBuzzing, roomId: roomId);
  }

  Future<void> selectCatTarget(String roomId, String targetUid) async {
    await _callCommand(
      command: GameCommand.selectCatTarget,
      roomId: roomId,
      data: {'targetUid': targetUid},
    );
  }

  Future<void> setWagerAndOpen({
    required String roomId,
    required int wager,
  }) async {
    await _callCommand(
      command: GameCommand.setWagerAndOpen,
      roomId: roomId,
      data: {'wager': wager},
    );
  }

  Future<void> buzz(String roomId) async {
    await _callCommand(command: GameCommand.buzz, roomId: roomId);
  }

  Future<void> submitAnswer(String roomId) async {
    await _callCommand(command: GameCommand.submitAnswer, roomId: roomId);
  }

  Future<void> submitNumericAnswer({
    required String roomId,
    required num value,
  }) async {
    await _callCommand(
      command: GameCommand.submitNumericAnswer,
      roomId: roomId,
      data: {'value': value},
    );
  }

  Future<void> addQuestions({
    required String roomId,
    required List<QuestionDraft> drafts,
  }) async {
    if (drafts.isEmpty) {
      return;
    }
    for (var i = 0; i < drafts.length; i += 500) {
      final chunk = drafts.sublist(
        i,
        (i + 500) > drafts.length ? drafts.length : i + 500,
      );
      await _callCommand(
        command: GameCommand.addQuestionsBulk,
        roomId: roomId,
        data: {
          'questions': chunk
              .map(
                (draft) => {
                  'theme': draft.theme,
                  'text': draft.text,
                  'answer': draft.answer,
                  'cost': draft.cost,
                  'round': draft.round,
                  'type': draft.type.value,
                  'mediaUrl': draft.mediaUrl,
                  'mediaType': draft.mediaType.value,
                  'aliases': draft.aliases,
                },
              )
              .toList(),
        },
      );
    }
  }

  Future<void> judgeAnswer({
    required String roomId,
    required bool correct,
  }) async {
    await _callCommand(
      command: GameCommand.judgeAnswer,
      roomId: roomId,
      data: {'correct': correct},
    );
  }

  Future<void> applyScore({
    required String roomId,
    required String targetUid,
    required int delta,
  }) async {
    await _callCommand(
      command: GameCommand.applyScore,
      roomId: roomId,
      data: {'targetUid': targetUid, 'delta': delta},
    );
  }

  Future<void> pauseGame(String roomId) async {
    await _callCommand(command: GameCommand.pauseGame, roomId: roomId);
  }

  Future<void> resumeGame(String roomId) async {
    await _callCommand(command: GameCommand.resumeGame, roomId: roomId);
  }

  Future<void> handleTimerExpiration(String roomId) async {
    await _callCommand(
      command: GameCommand.handleTimerExpiration,
      roomId: roomId,
    );
  }

  Future<Map<String, dynamic>> _callCommand({
    required GameCommand command,
    String? roomId,
    Map<String, dynamic>? data,
  }) async {
    final callable = functions.httpsCallable('gameCommand');
    try {
      final payload = <String, dynamic>{'command': command.value};
      if (roomId != null) payload['roomId'] = roomId;
      if (data != null) payload['data'] = data;
      final response = await callable.call(payload);
      final raw = response.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw AppException(message: e.message ?? 'Server error', code: e.code);
    }
  }

  Future<void> _storeLastRoom(String roomId, {required PlayerRole role}) async {
    final prefs = await getSharedPreferencesCached();
    await prefs.setString('last_room_id', roomId);
    await prefs.setString('last_room_role', role.value);
  }
}
