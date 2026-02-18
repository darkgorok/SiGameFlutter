import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRooms() {
    return firestore
        .collection('rooms')
        .orderBy('createdAt', descending: true)
        .snapshots();
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
      command: 'upsert_profile',
      data: {'uid': uid, 'nickname': nickname, 'avatarUrl': avatarUrl},
    );
  }

  Future<String> createRoom({
    required String roomName,
    String? password,
  }) async {
    final normalizedPassword = password?.trim() ?? '';
    final data = await _callCommand(
      command: 'create_room',
      data: {
        'roomName': roomName,
        if (normalizedPassword.isNotEmpty) 'password': normalizedPassword,
      },
    );
    final roomId = data['roomId'] as String?;
    if (roomId == null || roomId.isEmpty) {
      throw Exception('Server did not return roomId');
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
      command: 'join_room',
      roomId: roomId,
      data: {
        'role': role.value,
        if (normalizedPassword.isNotEmpty) 'password': normalizedPassword,
      },
    );
    await _storeLastRoom(roomId, role: role);
  }

  Future<void> markDisconnected(String roomId) async {
    await _callCommand(command: 'mark_disconnected', roomId: roomId);
  }

  Future<void> addQuestion({
    required String roomId,
    required QuestionDraft draft,
  }) async {
    await _callCommand(
      command: 'add_question',
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
      command: 'set_player_role',
      roomId: roomId,
      data: {'targetUid': targetUid, 'role': role.value},
    );
  }

  Future<void> kickPlayer({
    required String roomId,
    required String targetUid,
  }) async {
    await _callCommand(
      command: 'kick_player',
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
      command: 'ban_player',
      roomId: roomId,
      data: {'targetUid': targetUid, 'reason': reason},
    );
  }

  Future<void> unbanPlayer({
    required String roomId,
    required String targetUid,
  }) async {
    await _callCommand(
      command: 'unban_player',
      roomId: roomId,
      data: {'targetUid': targetUid},
    );
  }

  Future<PackSummary> savePack({
    required String roomId,
    required String name,
  }) async {
    final data = await _callCommand(
      command: 'save_pack',
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
    final data = await _callCommand(command: 'list_packs');
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
      command: 'apply_pack',
      roomId: roomId,
      data: {'packId': packId},
    );
  }

  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final data = await _callCommand(command: 'get_leaderboard');
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
    await _callCommand(command: 'start_game', roomId: roomId);
  }

  Future<void> advanceToRound2(String roomId) async {
    await _callCommand(command: 'advance_round2', roomId: roomId);
  }

  Future<void> startFinalRound(String roomId) async {
    await _callCommand(command: 'start_final_round', roomId: roomId);
  }

  Future<void> setFinalQuestion({
    required String roomId,
    required String theme,
    required String question,
    required String answer,
  }) async {
    await _callCommand(
      command: 'set_final_question',
      roomId: roomId,
      data: {'theme': theme, 'question': question, 'answer': answer},
    );
  }

  Future<void> openFinalWagers(String roomId) async {
    await _callCommand(command: 'open_final_wagers', roomId: roomId);
  }

  Future<void> openFinalAnswers(String roomId) async {
    await _callCommand(command: 'open_final_answers', roomId: roomId);
  }

  Future<void> submitFinalWager({
    required String roomId,
    required int wager,
  }) async {
    await _callCommand(
      command: 'submit_final_wager',
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
      command: 'set_final_player_result',
      roomId: roomId,
      data: {'targetUid': targetUid, 'result': result.value},
    );
  }

  Future<void> revealFinal(String roomId) async {
    await _callCommand(command: 'reveal_final', roomId: roomId);
  }

  Future<void> pickQuestion({
    required String roomId,
    required String questionId,
  }) async {
    await _callCommand(
      command: 'pick_question',
      roomId: roomId,
      data: {'questionId': questionId},
    );
  }

  Future<void> openBuzzing(String roomId) async {
    await _callCommand(command: 'open_buzzing', roomId: roomId);
  }

  Future<void> selectCatTarget(String roomId, String targetUid) async {
    await _callCommand(
      command: 'select_cat_target',
      roomId: roomId,
      data: {'targetUid': targetUid},
    );
  }

  Future<void> setWagerAndOpen({
    required String roomId,
    required int wager,
  }) async {
    await _callCommand(
      command: 'set_wager_and_open',
      roomId: roomId,
      data: {'wager': wager},
    );
  }

  Future<void> buzz(String roomId) async {
    await _callCommand(command: 'buzz', roomId: roomId);
  }

  Future<void> submitAnswer(String roomId) async {
    await _callCommand(command: 'submit_answer', roomId: roomId);
  }

  Future<void> submitNumericAnswer({
    required String roomId,
    required num value,
  }) async {
    await _callCommand(
      command: 'submit_numeric_answer',
      roomId: roomId,
      data: {'value': value},
    );
  }

  Future<void> judgeAnswer({
    required String roomId,
    required bool correct,
  }) async {
    await _callCommand(
      command: 'judge_answer',
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
      command: 'apply_score',
      roomId: roomId,
      data: {'targetUid': targetUid, 'delta': delta},
    );
  }

  Future<void> pauseGame(String roomId) async {
    await _callCommand(command: 'pause_game', roomId: roomId);
  }

  Future<void> resumeGame(String roomId) async {
    await _callCommand(command: 'resume_game', roomId: roomId);
  }

  Future<void> handleTimerExpiration(String roomId) async {
    await _callCommand(command: 'handle_timer_expiration', roomId: roomId);
  }

  Future<Map<String, dynamic>> _callCommand({
    required String command,
    String? roomId,
    Map<String, dynamic>? data,
  }) async {
    final callable = functions.httpsCallable('gameCommand');
    try {
      final payload = <String, dynamic>{'command': command};
      if (roomId != null) payload['roomId'] = roomId;
      if (data != null) payload['data'] = data;
      final response = await callable.call(payload);
      final raw = response.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Server error');
    }
  }

  Future<void> _storeLastRoom(String roomId, {required PlayerRole role}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_room_id', roomId);
    await prefs.setString('last_room_role', role.value);
  }
}
