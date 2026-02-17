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
        .limit(100)
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

  Future<String> createRoom({required String roomName}) async {
    final data = await _callCommand(
      command: 'create_room',
      data: {'roomName': roomName},
    );
    final roomId = data['roomId'] as String?;
    if (roomId == null || roomId.isEmpty) {
      throw Exception('Сервер не вернул roomId');
    }
    await _storeLastRoom(roomId);
    return roomId;
  }

  Future<void> joinRoom(String roomId) async {
    await _callCommand(command: 'join_room', roomId: roomId);
    await _storeLastRoom(roomId);
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
      },
    );
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

  Future<void> submitFinalAnswer({
    required String roomId,
    required String answer,
  }) async {
    await _callCommand(
      command: 'submit_final_answer',
      roomId: roomId,
      data: {'answer': answer},
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

  Future<void> submitAnswer(String roomId, String answer) async {
    await _callCommand(
      command: 'submit_answer',
      roomId: roomId,
      data: {'answer': answer},
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
      throw Exception(e.message ?? 'Ошибка сервера');
    }
  }

  Future<void> _storeLastRoom(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_room_id', roomId);
  }
}
