import 'package:firebase_auth/firebase_auth.dart';

import '../../game_models.dart';

class GameUiPermissions {
  static bool canPickQuestion(RoomModel room) {
    if (room.status == GameStatus.paused ||
        room.phase != GamePhase.boardSelect) {
      return false;
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return room.chooserUid == uid || room.hostUid == uid;
  }

  static bool canBuzz(RoomModel room, String uid) {
    if (room.phase != GamePhase.answering || room.status == GameStatus.paused) {
      return false;
    }
    if (room.activeQuestion?.type == QuestionType.closestNumber) {
      return false;
    }
    if (room.currentAttemptUid != null) {
      return false;
    }
    if (room.buzzQueue.contains(uid)) {
      return false;
    }
    if (room.targetedUid != null && room.targetedUid != uid) {
      return false;
    }
    return true;
  }
}
