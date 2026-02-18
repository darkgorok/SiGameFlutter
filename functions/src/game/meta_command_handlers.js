const crypto = require('crypto');

function hashRoomPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

function createMetaCommandHandlers(deps) {
  const {
    db,
    FieldValue,
    functionsLib,
    GAME_STATUS,
    GAME_PHASE,
    PLAYER_ROLE,
    FINAL_RESULT,
    ENGINE_STAGE,
    GAME_TIMER_MS,
    getProfile,
    logEvent,
  } = deps;

  return {
    async create_room({ uid, payload }) {
      const roomName = String(payload.roomName || 'Room').trim() || 'Room';
      const rawPassword = String(payload.password || '').trim();
      const hasPassword = rawPassword.length > 0;
      const passwordHash = hasPassword ? hashRoomPassword(rawPassword) : null;
      const profile = await getProfile(uid);
      const roomRef = db.collection('rooms').doc();

      await roomRef.set({
        name: roomName,
        hostUid: uid,
        passwordProtected: hasPassword,
        hasPassword,
        passwordRequired: hasPassword,
        status: GAME_STATUS.LOBBY,
        phase: GAME_PHASE.LOBBY,
        engineStage: ENGINE_STAGE.BEGIN,
        currentRound: 1,
        chooserUid: uid,
        pausedByUid: null,
        currentQuestionId: null,
        activeQuestion: null,
        buzzQueue: [],
        currentAttemptUid: null,
        pendingAnswer: null,
        appealActive: false,
        appealRequestedByUid: null,
        appealForUid: null,
        targetedUid: null,
        wagerValue: null,
        numericAnswers: null,
        timerDeadlineAtMs: null,
        timerRemainingMs: null,
        finalTheme: null,
        finalQuestion: null,
        finalAnswer: null,
        finalThemePool: [],
        finalThemeDeleteOrder: [],
        finalThemeDeleteCandidates: [],
        finalThemeDeleteNeedsSelection: false,
        finalThemeDeleteIndex: 0,
        finalThemeDeleteCurrentUid: null,
        finalAnswerOrder: [],
        finalAnswerIndex: 0,
        finalAnswerCurrentUid: null,
        finalRevealOrder: [],
        finalRevealIndex: 0,
        finalRevealCurrentUid: null,
        finalEligibleUids: [],
        rules: {
          falseStartEnabled: false,
          useAppeals: false,
          timers: {
            QUESTION_REVEAL: GAME_TIMER_MS.QUESTION_REVEAL,
            CAT_SELECTION: GAME_TIMER_MS.CAT_SELECTION,
            WAGER_SELECTION: GAME_TIMER_MS.WAGER_SELECTION,
            PRESSING: GAME_TIMER_MS.PRESSING,
            BUTTON_BLOCKING: GAME_TIMER_MS.BUTTON_BLOCKING,
            ANSWERING: GAME_TIMER_MS.ANSWERING,
            ANSWER_REVIEW: GAME_TIMER_MS.ANSWER_REVIEW,
            FINAL_WAGERING: GAME_TIMER_MS.FINAL_WAGERING,
            FINAL_ANSWERING: GAME_TIMER_MS.FINAL_ANSWERING,
            FINAL_REVEAL_STEP: GAME_TIMER_MS.FINAL_REVEAL_STEP,
          },
        },
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      if (hasPassword && passwordHash) {
        await roomRef.collection('meta').doc('security').set({
          passwordHash,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      await roomRef.collection('players').doc(uid).set({
        nickname: profile.nickname || 'Player',
        avatarUrl: profile.avatarUrl || '',
        role: PLAYER_ROLE.HOST,
        score: 0,
        connected: true,
        isHost: true,
        correctAnswers: 0,
        wrongAnswers: 0,
        buzzCount: 0,
        finalWager: 0,
        finalWagerSubmitted: false,
        finalAnswerSubmitted: false,
        finalAnswerText: null,
        finalAnswerSubmittedAt: null,
        finalResult: FINAL_RESULT.PENDING,
        finalAnswer: null,
      });

      await logEvent(roomRef.id, uid, 'room_created', 'Room created');
      return { roomId: roomRef.id };
    },

    async upsert_profile({ uid, payload }) {
      const nickname = String(payload.nickname || '').trim() || 'Player';
      const avatarUrl = String(payload.avatarUrl || '').trim();
      const nicknameLower = nickname.toLowerCase();

      const profileRef = db.collection('profiles').doc(uid);
      const nicknameRef = db.collection('nickname_index').doc(nicknameLower);

      await db.runTransaction(async (tx) => {
        const profileSnap = await tx.get(profileRef);
        const currentProfile = profileSnap.data() || {};
        const currentLower = String(currentProfile.nicknameLower || '').trim().toLowerCase();

        const nicknameSnap = await tx.get(nicknameRef);
        const nicknameOwner = String(nicknameSnap.data()?.uid || '').trim();
        if (nicknameSnap.exists && nicknameOwner && nicknameOwner !== uid) {
          throw new functionsLib.https.HttpsError('already-exists', 'Nickname already taken');
        }

        if (currentLower && currentLower !== nicknameLower) {
          const oldNicknameRef = db.collection('nickname_index').doc(currentLower);
          const oldNicknameSnap = await tx.get(oldNicknameRef);
          const oldOwner = String(oldNicknameSnap.data()?.uid || '').trim();
          if (oldNicknameSnap.exists && oldOwner === uid) {
            tx.delete(oldNicknameRef);
          }
        }

        tx.set(
          nicknameRef,
          {
            uid,
            nickname,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        tx.set(
          profileRef,
          {
            nickname,
            nicknameLower,
            avatarUrl,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      });

      return { ok: true };
    },

    async list_packs() {
      const snaps = await db
        .collection('packs')
        .orderBy('updatedAt', 'desc')
        .limit(30)
        .get();
      return {
        packs: snaps.docs.map((d) => ({
          id: d.id,
          name: d.data().name || d.id,
          version: Number(d.data().version || 1),
          questionCount: Number(d.data().questionCount || 0),
          updatedAt: d.data().updatedAt || null,
        })),
      };
    },
  };
}

module.exports = {
  createMetaCommandHandlers,
};
