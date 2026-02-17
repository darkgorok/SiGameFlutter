const admin = require('firebase-admin');
const functions = require('firebase-functions/v1');

admin.initializeApp();

const db = admin.firestore();
const { FieldValue } = admin.firestore;

const GAME_STATUS = {
  LOBBY: 'lobby',
  IN_GAME: 'in_game',
  PAUSED: 'paused',
  FINAL_ROUND: 'final_round',
  COMPLETED: 'completed',
};

const GAME_PHASE = {
  LOBBY: 'lobby',
  BOARD_SELECT: 'board_select',
  QUESTION_REVEAL: 'question_reveal',
  CAT_TARGETING: 'cat_targeting',
  WAGER_BIDDING: 'wager_bidding',
  ANSWERING: 'answering',
  ANSWER_REVIEW: 'answer_review',
  FINAL_SETUP: 'final_setup',
  FINAL_WAGERING: 'final_wagering',
  FINAL_ANSWERING: 'final_answering',
  GAME_OVER: 'game_over',
};

const PLAYER_ROLE = {
  HOST: 'host',
  PLAYER: 'player',
  SPECTATOR: 'spectator',
  EDITOR: 'editor',
};

const FINAL_RESULT = {
  PENDING: 'pending',
  CORRECT: 'correct',
  WRONG: 'wrong',
  NO_ANSWER: 'no_answer',
};

const ALLOWED_JOIN_ROLES = new Set([
  PLAYER_ROLE.PLAYER,
  PLAYER_ROLE.SPECTATOR,
  PLAYER_ROLE.EDITOR,
]);

async function getProfile(uid) {
  const snap = await db.collection('profiles').doc(uid).get();
  return snap.data() || {};
}

async function getPlayerRole(roomRef, uid, tx = null) {
  const playerRef = roomRef.collection('players').doc(uid);
  const snap = tx ? await tx.get(playerRef) : await playerRef.get();
  return snap.data()?.role || null;
}

async function assertRoomMember(roomRef, uid, tx = null) {
  const role = await getPlayerRole(roomRef, uid, tx);
  if (!role) {
    throw new functions.https.HttpsError('permission-denied', 'Только участник комнаты');
  }
  return role;
}

function canEditContent(role) {
  return role === PLAYER_ROLE.HOST || role === PLAYER_ROLE.EDITOR;
}

function normalizeAliases(raw) {
  if (!Array.isArray(raw)) {
    return [];
  }
  const cleaned = raw
    .map((v) => String(v || '').trim())
    .filter((v) => v.length > 0);
  return [...new Set(cleaned)].slice(0, 20);
}

async function logEvent(roomId, actorUid, type, message) {
  await db.collection('rooms').doc(roomId).collection('events').add({
    actorUid,
    type,
    message,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function requireAuth(context) {
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  }
  return context.auth.uid;
}

async function requireHost(roomRef, uid, tx = null) {
  const roomSnap = tx ? await tx.get(roomRef) : await roomRef.get();
  if (!roomSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Room not found');
  }
  if (roomSnap.data().hostUid !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'Host only');
  }
  return roomSnap;
}

function normalizeAnswer(value) {
  return String(value || '').trim().toLowerCase();
}

function ensureVoiceRole(role) {
  return role !== PLAYER_ROLE.SPECTATOR;
}

async function revealFinalByHost(roomRef, roomId, hostUid) {
  await requireHost(roomRef, hostUid);
  const roomSnap = await roomRef.get();
  const room = roomSnap.data() || {};
  const eligible = Array.isArray(room.finalEligibleUids)
    ? room.finalEligibleUids
    : [];
  const players = await roomRef.collection('players').get();
  const batch = db.batch();

  players.docs.forEach((p) => {
    if (!eligible.includes(p.id)) {
      batch.set(p.ref, { finalRevealed: true }, { merge: true });
      return;
    }

    const player = p.data();
    const wager = Number(player.finalWager || 0);
    const result = String(player.finalResult || FINAL_RESULT.PENDING);
    const correct = result === FINAL_RESULT.CORRECT;
    const wrong = result === FINAL_RESULT.WRONG;
    const delta = correct ? wager : wrong ? -wager : 0;

    batch.set(
      p.ref,
      {
        score: FieldValue.increment(delta),
        correctAnswers: FieldValue.increment(correct ? 1 : 0),
        wrongAnswers: FieldValue.increment(wrong ? 1 : 0),
        finalRevealed: true,
      },
      { merge: true },
    );
  });

  batch.update(roomRef, {
    phase: GAME_PHASE.GAME_OVER,
    status: GAME_STATUS.COMPLETED,
    timerDeadlineAtMs: null,
    timerRemainingMs: null,
    updatedAt: FieldValue.serverTimestamp(),
  });

  await batch.commit();
  await logEvent(roomId, hostUid, 'final_reveal', 'Финал вскрыт, игра завершена');
}

async function autoAdvanceRoundIfNeeded(roomRef) {
  const roomSnap = await roomRef.get();
  if (!roomSnap.exists) {
    return;
  }
  const room = roomSnap.data() || {};
  const currentRound = Number(room.currentRound || 1);
  if (currentRound !== 1) {
    return;
  }
  const remain = await roomRef
    .collection('questions')
    .where('round', '==', currentRound)
    .where('used', '==', false)
    .count()
    .get();
  const left = Number(remain.data().count || 0);
  if (left === 0) {
    await roomRef.update({
      currentRound: 2,
      phase: GAME_PHASE.BOARD_SELECT,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
}

async function handleTimerExpirationByHost(roomRef, roomId, hostUid) {
  let shouldRevealFinal = false;

  await db.runTransaction(async (tx) => {
    const roomSnap = await tx.get(roomRef);
    if (!roomSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Room not found');
    }
    const room = roomSnap.data();

    if (room.hostUid !== hostUid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Только ведущий может завершать этап по таймеру',
      );
    }

    if (
      !room.timerDeadlineAtMs ||
      Date.now() < Number(room.timerDeadlineAtMs) ||
      room.status === GAME_STATUS.PAUSED
    ) {
      return;
    }

    if (room.phase === GAME_PHASE.QUESTION_REVEAL) {
      tx.update(roomRef, {
        phase: GAME_PHASE.ANSWERING,
        timerDeadlineAtMs: Date.now() + 5000,
        timerRemainingMs: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    if (room.phase === GAME_PHASE.ANSWERING) {
      const current = room.currentAttemptUid;
      if (current) {
        const amount = Number(room.wagerValue || room.activeQuestion?.cost || 0);
        tx.set(
          roomRef.collection('players').doc(current),
          {
            score: FieldValue.increment(-amount),
            wrongAnswers: FieldValue.increment(1),
          },
          { merge: true },
        );
      }

      tx.update(roomRef, {
        phase: GAME_PHASE.BOARD_SELECT,
        currentQuestionId: null,
        activeQuestion: null,
        buzzQueue: [],
        currentAttemptUid: null,
        pendingAnswer: null,
        targetedUid: null,
        wagerValue: null,
        timerDeadlineAtMs: null,
        timerRemainingMs: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    if (room.phase === GAME_PHASE.FINAL_WAGERING) {
      tx.update(roomRef, {
        phase: GAME_PHASE.FINAL_ANSWERING,
        timerDeadlineAtMs: Date.now() + 45000,
        timerRemainingMs: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    if (room.phase === GAME_PHASE.FINAL_ANSWERING) {
      shouldRevealFinal = true;
    }
  });

  if (shouldRevealFinal) {
    await revealFinalByHost(roomRef, roomId, hostUid);
  }
  await logEvent(roomId, hostUid, 'timer_expire', 'Этап завершен по таймеру');
}

exports.gameCommand = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const command = String(data?.command || '');
  const payload = data?.data || {};

  if (!command) {
    throw new functions.https.HttpsError('invalid-argument', 'command required');
  }

  if (command === 'create_room') {
    const roomName = String(payload.roomName || 'Комната').trim() || 'Комната';
    const profile = await getProfile(uid);
    const roomRef = db.collection('rooms').doc();

    await roomRef.set({
      name: roomName,
      hostUid: uid,
      status: GAME_STATUS.LOBBY,
      phase: GAME_PHASE.LOBBY,
      currentRound: 1,
      chooserUid: uid,
      pausedByUid: null,
      currentQuestionId: null,
      activeQuestion: null,
      buzzQueue: [],
      currentAttemptUid: null,
      pendingAnswer: null,
      targetedUid: null,
      wagerValue: null,
      timerDeadlineAtMs: null,
      timerRemainingMs: null,
      finalTheme: null,
      finalQuestion: null,
      finalAnswer: null,
      finalEligibleUids: [],
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await roomRef.collection('players').doc(uid).set({
      nickname: profile.nickname || 'Игрок',
      avatarUrl: profile.avatarUrl || '',
      role: PLAYER_ROLE.HOST,
      score: 0,
      connected: true,
      isHost: true,
      correctAnswers: 0,
      wrongAnswers: 0,
      buzzCount: 0,
      finalWager: 0,
      finalResult: FINAL_RESULT.PENDING,
      finalAnswer: null,
    });

    await logEvent(roomRef.id, uid, 'room_created', 'Комната создана');
    return { roomId: roomRef.id };
  }

  if (command === 'upsert_profile') {
    const nickname = String(payload.nickname || '').trim() || 'Игрок';
    const avatarUrl = String(payload.avatarUrl || '').trim();
    await db
      .collection('profiles')
      .doc(uid)
      .set(
        {
          nickname,
          avatarUrl,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    return { ok: true };
  }

  if (command === 'list_packs') {
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
  }

  const roomId = String(data?.roomId || payload.roomId || '');
  if (!roomId) {
    throw new functions.https.HttpsError('invalid-argument', 'roomId required');
  }

  const roomRef = db.collection('rooms').doc(roomId);

  if (command === 'join_room') {
    const profile = await getProfile(uid);
    const requestedRole = String(payload.role || PLAYER_ROLE.PLAYER);
    const allowedRole = ALLOWED_JOIN_ROLES.has(requestedRole)
      ? requestedRole
      : PLAYER_ROLE.PLAYER;
    const hasProfileNickname = typeof profile.nickname === 'string';
    const hasProfileAvatarUrl = typeof profile.avatarUrl === 'string';
    const profileNickname = String(profile.nickname || '').trim();
    const profileAvatarUrl = String(profile.avatarUrl || '').trim();

    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Room not found');
      }
      const banSnap = await tx.get(roomRef.collection('bans').doc(uid));
      if (banSnap.exists) {
        throw new functions.https.HttpsError('permission-denied', 'Вы заблокированы в этой комнате');
      }
      const room = roomSnap.data() || {};
      const isHost = room.hostUid === uid;
      const playerRef = roomRef.collection('players').doc(uid);
      const playerSnap = await tx.get(playerRef);
      const existing = playerSnap.data() || {};
      const role = isHost ? PLAYER_ROLE.HOST : allowedRole;

      tx.set(
        playerRef,
        {
          nickname: hasProfileNickname
            ? (profileNickname || 'Игрок')
            : (existing.nickname || 'Игрок'),
          avatarUrl: hasProfileAvatarUrl
            ? profileAvatarUrl
            : (existing.avatarUrl || ''),
          role,
          connected: true,
          score: playerSnap.exists
            ? FieldValue.increment(0)
            : Number(existing.score || 0),
          isHost,
          correctAnswers: playerSnap.exists
            ? FieldValue.increment(0)
            : Number(existing.correctAnswers || 0),
          wrongAnswers: playerSnap.exists
            ? FieldValue.increment(0)
            : Number(existing.wrongAnswers || 0),
          buzzCount: playerSnap.exists
            ? FieldValue.increment(0)
            : Number(existing.buzzCount || 0),
          finalWager: playerSnap.exists
            ? FieldValue.increment(0)
            : Number(existing.finalWager || 0),
          finalResult: existing.finalResult || FINAL_RESULT.PENDING,
        },
        { merge: true },
      );
      tx.update(roomRef, { updatedAt: FieldValue.serverTimestamp() });
    });
    await logEvent(roomId, uid, 'join', 'Игрок вошел в комнату');
    return { ok: true };
  }

  if (command === 'set_player_role') {
    const targetUid = String(payload.targetUid || '');
    const role = String(payload.role || PLAYER_ROLE.PLAYER);
    if (!targetUid || targetUid === uid) {
      throw new functions.https.HttpsError('invalid-argument', 'targetUid required');
    }
    if (!ALLOWED_JOIN_ROLES.has(role)) {
      throw new functions.https.HttpsError('invalid-argument', 'invalid role');
    }
    const roomSnap = await requireHost(roomRef, uid);
    const room = roomSnap.data() || {};
    if (room.hostUid === targetUid) {
      throw new functions.https.HttpsError('failed-precondition', 'Нельзя менять роль ведущего');
    }
    await roomRef.collection('players').doc(targetUid).set({ role }, { merge: true });
    await logEvent(roomId, uid, 'role_change', 'Роль игрока изменена');
    return { ok: true };
  }

  if (command === 'kick_player') {
    const targetUid = String(payload.targetUid || '');
    if (!targetUid || targetUid === uid) {
      throw new functions.https.HttpsError('invalid-argument', 'targetUid required');
    }
    const roomSnap = await requireHost(roomRef, uid);
    const room = roomSnap.data() || {};
    if (room.hostUid === targetUid) {
      throw new functions.https.HttpsError('failed-precondition', 'Нельзя кикнуть ведущего');
    }
    await roomRef.collection('players').doc(targetUid).set(
      { connected: false, kickedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    await logEvent(roomId, uid, 'kick', 'Игрок кикнут из комнаты');
    return { ok: true };
  }

  if (command === 'ban_player') {
    const targetUid = String(payload.targetUid || '');
    const reason = String(payload.reason || '').trim();
    if (!targetUid || targetUid === uid) {
      throw new functions.https.HttpsError('invalid-argument', 'targetUid required');
    }
    const roomSnap = await requireHost(roomRef, uid);
    const room = roomSnap.data() || {};
    if (room.hostUid === targetUid) {
      throw new functions.https.HttpsError('failed-precondition', 'Нельзя банить ведущего');
    }
    const batch = db.batch();
    batch.set(
      roomRef.collection('bans').doc(targetUid),
      {
        uid: targetUid,
        reason,
        bannedBy: uid,
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    batch.set(
      roomRef.collection('players').doc(targetUid),
      { connected: false, role: PLAYER_ROLE.SPECTATOR },
      { merge: true },
    );
    await batch.commit();
    await logEvent(roomId, uid, 'ban', 'Игрок забанен');
    return { ok: true };
  }

  if (command === 'unban_player') {
    const targetUid = String(payload.targetUid || '');
    if (!targetUid) {
      throw new functions.https.HttpsError('invalid-argument', 'targetUid required');
    }
    await requireHost(roomRef, uid);
    await roomRef.collection('bans').doc(targetUid).delete();
    await logEvent(roomId, uid, 'unban', 'Бан игрока снят');
    return { ok: true };
  }

  if (command === 'mark_disconnected') {
    await roomRef.collection('players').doc(uid).set({ connected: false }, { merge: true });
    return { ok: true };
  }

  if (command === 'add_question') {
    await requireHost(roomRef, uid);
    await roomRef.collection('questions').add({
      theme: String(payload.theme || '').trim() || 'Без темы',
      text: String(payload.text || ''),
      cost: Number(payload.cost || 100),
      round: Number(payload.round || 1),
      type: String(payload.type || 'normal'),
      mediaUrl: String(payload.mediaUrl || ''),
      mediaType: String(payload.mediaType || 'none'),
      aliases: normalizeAliases(payload.aliases || []),
      used: false,
      createdBy: uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    await logEvent(roomId, uid, 'question_add', 'Добавлен вопрос');
    return { ok: true };
  }

  if (command === 'save_pack') {
    const role = await assertRoomMember(roomRef, uid);
    if (!canEditContent(role)) {
      throw new functions.https.HttpsError('permission-denied', 'Только ведущий или редактор');
    }
    const packName = String(payload.name || '').trim() || `Pack-${roomId}`;
    const questions = await roomRef.collection('questions').get();
    const items = questions.docs.map((q) => ({
      theme: q.data().theme || 'Без темы',
      text: q.data().text || '',
      cost: Number(q.data().cost || 100),
      round: Number(q.data().round || 1),
      type: q.data().type || 'normal',
      mediaUrl: q.data().mediaUrl || '',
      mediaType: q.data().mediaType || 'none',
      aliases: normalizeAliases(q.data().aliases || []),
    }));

    const existing = await db
      .collection('packs')
      .where('name', '==', packName)
      .orderBy('version', 'desc')
      .limit(1)
      .get();
    const version = existing.empty ? 1 : Number(existing.docs.first.data().version || 1) + 1;
    const packRef = db.collection('packs').doc();
    await packRef.set({
      name: packName,
      version,
      questionCount: items.length,
      questions: items,
      createdBy: uid,
      roomId,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await logEvent(roomId, uid, 'pack_save', `Пакет сохранен: ${packName} v${version}`);
    return { ok: true, packId: packRef.id, version };
  }

  if (command === 'apply_pack') {
    const packId = String(payload.packId || '');
    if (!packId) {
      throw new functions.https.HttpsError('invalid-argument', 'packId required');
    }
    const role = await assertRoomMember(roomRef, uid);
    if (!(role === PLAYER_ROLE.HOST || role === PLAYER_ROLE.EDITOR)) {
      throw new functions.https.HttpsError('permission-denied', 'Только ведущий или редактор');
    }
    const packSnap = await db.collection('packs').doc(packId).get();
    if (!packSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Pack not found');
    }
    const pack = packSnap.data() || {};
    const questions = Array.isArray(pack.questions) ? pack.questions : [];
    const batch = db.batch();
    for (const q of questions.slice(0, 500)) {
      const qRef = roomRef.collection('questions').doc();
      batch.set(qRef, {
        theme: String(q.theme || 'Без темы'),
        text: String(q.text || ''),
        cost: Number(q.cost || 100),
        round: Number(q.round || 1),
        type: String(q.type || 'normal'),
        mediaUrl: String(q.mediaUrl || ''),
        mediaType: String(q.mediaType || 'none'),
        aliases: normalizeAliases(q.aliases || []),
        used: false,
        createdBy: uid,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await logEvent(roomId, uid, 'pack_apply', `Пакет применен: ${pack.name || packId}`);
    return { ok: true, imported: questions.length };
  }

  if (command === 'start_game') {
    await requireHost(roomRef, uid);
    const questions = await roomRef.collection('questions').get();
    const batch = db.batch();
    questions.docs.forEach((q) => {
      batch.update(q.ref, { answer: FieldValue.delete() });
    });
    batch.update(roomRef, {
      status: GAME_STATUS.IN_GAME,
      phase: GAME_PHASE.BOARD_SELECT,
      currentRound: 1,
      chooserUid: uid,
      pausedByUid: null,
      finalAnswer: FieldValue.delete(),
      timerDeadlineAtMs: null,
      timerRemainingMs: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await logEvent(roomId, uid, 'start', 'Игра запущена');
    return { ok: true };
  }

  if (command === 'advance_round2') {
    await requireHost(roomRef, uid);
    await roomRef.update({
      currentRound: 2,
      phase: GAME_PHASE.BOARD_SELECT,
      status: GAME_STATUS.IN_GAME,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await logEvent(roomId, uid, 'round2', 'Переход во второй раунд');
    return { ok: true };
  }

  if (command === 'start_final_round') {
    await requireHost(roomRef, uid);
    const players = await roomRef.collection('players').get();
    const eligible = players.docs
      .filter((p) => {
        const score = Number(p.data().score || 0);
        const role = String(p.data().role || PLAYER_ROLE.PLAYER);
        return score > 0 && ensureVoiceRole(role);
      })
      .map((p) => p.id);

    await roomRef.update({
      status: GAME_STATUS.FINAL_ROUND,
      currentRound: 3,
      phase: GAME_PHASE.FINAL_SETUP,
      currentQuestionId: null,
      activeQuestion: null,
      finalEligibleUids: eligible,
      timerDeadlineAtMs: null,
      timerRemainingMs: null,
      updatedAt: FieldValue.serverTimestamp(),
    });

    await logEvent(roomId, uid, 'final_start', 'Запущен финальный раунд');
    return { ok: true, eligibleCount: eligible.length };
  }

  if (command === 'set_final_question') {
    await requireHost(roomRef, uid);
    await roomRef.update({
      finalTheme: String(payload.theme || ''),
      finalQuestion: String(payload.question || ''),
      phase: GAME_PHASE.FINAL_SETUP,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await logEvent(roomId, uid, 'final_question_set', 'Финальный вопрос задан');
    return { ok: true };
  }

  if (command === 'open_final_wagers') {
    await requireHost(roomRef, uid);
    const players = await roomRef.collection('players').get();
    const batch = db.batch();
    players.docs.forEach((p) => {
      batch.set(
        p.ref,
        {
          finalWager: 0,
          finalResult: FINAL_RESULT.PENDING,
          finalAnswer: null,
        },
        { merge: true },
      );
    });
    batch.update(roomRef, {
      phase: GAME_PHASE.FINAL_WAGERING,
      timerDeadlineAtMs: Date.now() + 45000,
      timerRemainingMs: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await logEvent(roomId, uid, 'final_wager_open', 'Открыты ставки финала');
    return { ok: true };
  }

  if (command === 'open_final_answers') {
    await requireHost(roomRef, uid);
    await roomRef.update({
      phase: GAME_PHASE.FINAL_ANSWERING,
      timerDeadlineAtMs: Date.now() + 90000,
      timerRemainingMs: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await logEvent(roomId, uid, 'final_answers_open', 'Начат этап голосовых ответов');
    return { ok: true };
  }

  if (command === 'submit_final_wager') {
    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Room not found');
      }
      const room = roomSnap.data();
      if (room.phase !== GAME_PHASE.FINAL_WAGERING) {
        throw new functions.https.HttpsError('failed-precondition', 'Ставки сейчас закрыты');
      }
      const eligible = Array.isArray(room.finalEligibleUids)
        ? room.finalEligibleUids
        : [];
      if (!eligible.includes(uid)) {
        throw new functions.https.HttpsError('permission-denied', 'Вы не участвуете в финале');
      }
      const playerRef = roomRef.collection('players').doc(uid);
      const playerSnap = await tx.get(playerRef);
      const score = Number(playerSnap.data()?.score || 0);
      const wager = Number(payload.wager || 0);
      const safeWager = Math.max(0, Math.min(wager, Math.max(score, 0)));
      tx.set(playerRef, { finalWager: safeWager }, { merge: true });
    });
    await logEvent(roomId, uid, 'final_wager', 'Ставка финала отправлена');
    return { ok: true };
  }

  if (command === 'set_final_player_result') {
    const targetUid = String(payload.targetUid || '');
    const result = String(payload.result || FINAL_RESULT.PENDING);
    const normalized = [
      FINAL_RESULT.CORRECT,
      FINAL_RESULT.WRONG,
      FINAL_RESULT.NO_ANSWER,
      FINAL_RESULT.PENDING,
    ].includes(result)
      ? result
      : FINAL_RESULT.PENDING;

    await requireHost(roomRef, uid);
    const roomSnap = await roomRef.get();
    const room = roomSnap.data() || {};
    if (room.phase !== GAME_PHASE.FINAL_ANSWERING) {
      throw new functions.https.HttpsError('failed-precondition', 'Этап финальных ответов не активен');
    }
    if (!targetUid) {
      throw new functions.https.HttpsError('invalid-argument', 'targetUid required');
    }
    const eligible = Array.isArray(room.finalEligibleUids)
      ? room.finalEligibleUids
      : [];
    if (!eligible.includes(targetUid)) {
      throw new functions.https.HttpsError('failed-precondition', 'Игрок не участвует в финале');
    }

    await roomRef.collection('players').doc(targetUid).set(
      { finalResult: normalized },
      { merge: true },
    );
    await logEvent(roomId, uid, 'final_mark', 'Ведущий выставил результат финального ответа');
    return { ok: true };
  }

  if (command === 'reveal_final') {
    await revealFinalByHost(roomRef, roomId, uid);
    return { ok: true };
  }

  if (command === 'pick_question') {
    const questionId = String(payload.questionId || '');
    if (!questionId) {
      throw new functions.https.HttpsError('invalid-argument', 'questionId required');
    }

    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Room not found');
      }
      const room = roomSnap.data();
      const qRef = roomRef.collection('questions').doc(questionId);
      const qSnap = await tx.get(qRef);
      if (!qSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Question not found');
      }
      const q = qSnap.data();

      if (room.status === GAME_STATUS.PAUSED) {
        throw new functions.https.HttpsError('failed-precondition', 'Игра на паузе');
      }
      if (room.phase !== GAME_PHASE.BOARD_SELECT) {
        throw new functions.https.HttpsError('failed-precondition', 'Нельзя выбрать вопрос сейчас');
      }
      if (room.chooserUid !== uid && room.hostUid !== uid) {
        throw new functions.https.HttpsError('permission-denied', 'Сейчас выбор у другого игрока');
      }
      if (q.used === true) {
        throw new functions.https.HttpsError('failed-precondition', 'Вопрос уже сыгран');
      }

      const type = String(q.type || 'normal');
      const phase = type === 'cat_in_bag'
        ? GAME_PHASE.CAT_TARGETING
        : type === 'wager'
          ? GAME_PHASE.WAGER_BIDDING
          : GAME_PHASE.QUESTION_REVEAL;

      tx.update(qRef, { used: true });
      tx.update(roomRef, {
        phase,
        currentQuestionId: questionId,
        activeQuestion: {
          id: questionId,
          theme: q.theme || 'Без темы',
          text: q.text || '',
          answer: '',
          cost: Number(q.cost || 100),
          type,
          mediaUrl: q.mediaUrl || '',
          mediaType: q.mediaType || 'none',
          aliases: normalizeAliases(q.aliases || []),
        },
        buzzQueue: [],
        currentAttemptUid: null,
        pendingAnswer: null,
        targetedUid: null,
        wagerValue: null,
        timerDeadlineAtMs: Date.now() + 20000,
        timerRemainingMs: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    await logEvent(roomId, uid, 'question_pick', 'Выбран вопрос');
    return { ok: true };
  }

  if (command === 'open_buzzing') {
    await db.runTransaction(async (tx) => {
      const roomSnap = await requireHost(roomRef, uid, tx);
      const room = roomSnap.data();
      if (room.phase !== GAME_PHASE.QUESTION_REVEAL) {
        throw new functions.https.HttpsError('failed-precondition', 'Неверный этап');
      }
      tx.update(roomRef, {
        phase: GAME_PHASE.ANSWERING,
        currentAttemptUid: null,
        pendingAnswer: null,
        timerDeadlineAtMs: Date.now() + 5000,
        timerRemainingMs: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    await logEvent(roomId, uid, 'buzz_open', 'Открыта кнопка ответа');
    return { ok: true };
  }

  if (command === 'select_cat_target') {
    const targetUid = String(payload.targetUid || '');
    if (!targetUid) {
      throw new functions.https.HttpsError('invalid-argument', 'targetUid required');
    }
    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Room not found');
      }
      const room = roomSnap.data();
      if (room.phase !== GAME_PHASE.CAT_TARGETING) {
        throw new functions.https.HttpsError('failed-precondition', 'Сейчас не этап кота в мешке');
      }
      if (room.chooserUid !== uid && room.hostUid !== uid) {
        throw new functions.https.HttpsError('permission-denied', 'Нет прав выбрать игрока');
      }
      const targetRole = await getPlayerRole(roomRef, targetUid, tx);
      if (!ensureVoiceRole(targetRole)) {
        throw new functions.https.HttpsError('failed-precondition', 'Нельзя выбрать зрителя');
      }
      tx.update(roomRef, {
        targetedUid: targetUid,
        phase: GAME_PHASE.ANSWERING,
        currentAttemptUid: targetUid,
        buzzQueue: [targetUid],
        timerDeadlineAtMs: Date.now() + 5000,
        timerRemainingMs: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(
        roomRef.collection('players').doc(targetUid),
        { buzzCount: FieldValue.increment(1) },
        { merge: true },
      );
    });
    await logEvent(roomId, uid, 'cat_target', 'Кот в мешке передан игроку');
    return { ok: true };
  }

  if (command === 'set_wager_and_open') {
    const wager = Number(payload.wager || 100);
    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);
      const room = roomSnap.data() || {};
      if (room.phase !== GAME_PHASE.WAGER_BIDDING) {
        throw new functions.https.HttpsError('failed-precondition', 'Ставка недоступна сейчас');
      }
      const actorUid = room.chooserUid || uid;
      const actorRef = roomRef.collection('players').doc(actorUid);
      const actorSnap = await tx.get(actorRef);
      const actorRole = actorSnap.data()?.role || PLAYER_ROLE.PLAYER;
      if (!ensureVoiceRole(actorRole)) {
        throw new functions.https.HttpsError('permission-denied', 'Зритель не может ставить');
      }
      const score = Number(actorSnap.data()?.score || 0);
      const maxWager = score > 0 ? score : Number(room.activeQuestion?.cost || 100);
      const safeWager = Math.max(100, Math.min(wager, maxWager));

      tx.update(roomRef, {
        wagerValue: safeWager,
        phase: GAME_PHASE.ANSWERING,
        currentAttemptUid: actorUid,
        buzzQueue: [actorUid],
        timerDeadlineAtMs: Date.now() + 5000,
        timerRemainingMs: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(actorRef, { buzzCount: FieldValue.increment(1) }, { merge: true });
    });
    await logEvent(roomId, uid, 'wager_set', 'Установлена ставка аукциона');
    return { ok: true };
  }

  if (command === 'buzz') {
    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);
      const room = roomSnap.data() || {};

      if (room.phase !== GAME_PHASE.ANSWERING || room.status === GAME_STATUS.PAUSED) {
        throw new functions.https.HttpsError('failed-precondition', 'Кнопка сейчас закрыта');
      }
      const role = await getPlayerRole(roomRef, uid, tx);
      if (!ensureVoiceRole(role)) {
        throw new functions.https.HttpsError('permission-denied', 'Зритель не участвует в ответах');
      }
      if (room.currentAttemptUid) {
        throw new functions.https.HttpsError('failed-precondition', 'Сейчас уже есть отвечающий игрок');
      }
      if (room.targetedUid && room.targetedUid !== uid) {
        throw new functions.https.HttpsError('failed-precondition', 'Это вопрос для другого игрока');
      }
      const queue = Array.isArray(room.buzzQueue) ? [...room.buzzQueue] : [];
      if (queue.includes(uid)) {
        throw new functions.https.HttpsError('failed-precondition', 'Вы уже в очереди');
      }
      queue.push(uid);
      tx.update(roomRef, {
        buzzQueue: queue,
        currentAttemptUid: uid,
        timerDeadlineAtMs: Date.now() + 5000,
        timerRemainingMs: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(
        roomRef.collection('players').doc(uid),
        { buzzCount: FieldValue.increment(1) },
        { merge: true },
      );
    });
    await logEvent(roomId, uid, 'buzz', 'Игрок нажал кнопку');
    return { ok: true };
  }

  if (command === 'submit_answer') {
    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);
      const room = roomSnap.data() || {};
      if (room.phase !== GAME_PHASE.ANSWERING) {
        throw new functions.https.HttpsError('failed-precondition', 'Нельзя отправить ответ на этом этапе');
      }
      if (room.currentAttemptUid !== uid) {
        throw new functions.https.HttpsError('permission-denied', 'Сейчас отвечает другой игрок');
      }
      tx.update(roomRef, {
        pendingAnswer: '[voice]',
        phase: GAME_PHASE.ANSWER_REVIEW,
        timerDeadlineAtMs: null,
        timerRemainingMs: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    await logEvent(roomId, uid, 'answer_submit', 'Игрок дал голосовой ответ');
    return { ok: true };
  }

  if (command === 'judge_answer') {
    const correct = !!payload.correct;

    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);
      const room = roomSnap.data() || {};
      if (room.hostUid !== uid) {
        throw new functions.https.HttpsError('permission-denied', 'Только ведущий принимает ответ');
      }
      if (room.phase !== GAME_PHASE.ANSWER_REVIEW || !room.activeQuestion) {
        throw new functions.https.HttpsError('failed-precondition', 'Сейчас нечего оценивать');
      }
      const playerUid = room.currentAttemptUid;
      if (!playerUid) {
        throw new functions.https.HttpsError('failed-precondition', 'Не определён игрок ответа');
      }

      const amount = Number(room.wagerValue || room.activeQuestion.cost || 0);
      const playerRef = roomRef.collection('players').doc(playerUid);
      tx.set(
        playerRef,
        {
          score: FieldValue.increment(correct ? amount : -amount),
          correctAnswers: FieldValue.increment(correct ? 1 : 0),
          wrongAnswers: FieldValue.increment(correct ? 0 : 1),
        },
        { merge: true },
      );

      if (correct) {
        tx.update(roomRef, {
          chooserUid: playerUid,
          phase: GAME_PHASE.BOARD_SELECT,
          currentQuestionId: null,
          activeQuestion: null,
          buzzQueue: [],
          currentAttemptUid: null,
          pendingAnswer: null,
          targetedUid: null,
          wagerValue: null,
          timerDeadlineAtMs: null,
          timerRemainingMs: null,
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        const queue = Array.isArray(room.buzzQueue) ? [...room.buzzQueue] : [];
        const idx = queue.indexOf(playerUid);
        if (idx >= 0) {
          queue.splice(idx, 1);
        }
        const oneShot = room.activeQuestion.type === 'cat_in_bag' || room.activeQuestion.type === 'wager';

        if (oneShot || queue.length === 0) {
          tx.update(roomRef, {
            phase: GAME_PHASE.BOARD_SELECT,
            currentQuestionId: null,
            activeQuestion: null,
            buzzQueue: [],
            currentAttemptUid: null,
            pendingAnswer: null,
            targetedUid: null,
            wagerValue: null,
            timerDeadlineAtMs: null,
            timerRemainingMs: null,
            updatedAt: FieldValue.serverTimestamp(),
          });
        } else {
          tx.update(roomRef, {
            phase: GAME_PHASE.ANSWERING,
            buzzQueue: queue,
            currentAttemptUid: queue[0],
            pendingAnswer: null,
            timerDeadlineAtMs: Date.now() + 5000,
            timerRemainingMs: null,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
    });

    await autoAdvanceRoundIfNeeded(roomRef);
    await logEvent(roomId, uid, 'judge', correct ? 'Ответ засчитан' : 'Ответ отклонен');
    return { ok: true };
  }

  if (command === 'apply_score') {
    const targetUid = String(payload.targetUid || '');
    const delta = Number(payload.delta || 0);
    await requireHost(roomRef, uid);
    await roomRef.collection('players').doc(targetUid).set(
      { score: FieldValue.increment(delta) },
      { merge: true },
    );
    await logEvent(roomId, uid, 'score_manual', 'Ручная корректировка счета');
    return { ok: true };
  }

  if (command === 'pause_game') {
    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);
      const room = roomSnap.data() || {};
      const role = await getPlayerRole(roomRef, uid, tx);
      if (uid !== room.hostUid && !ensureVoiceRole(role)) {
        throw new functions.https.HttpsError('permission-denied', 'Зритель не может ставить паузу');
      }
      if (room.status === GAME_STATUS.PAUSED) {
        return;
      }
      let remaining = null;
      if (room.timerDeadlineAtMs) {
        remaining = Math.max(0, Number(room.timerDeadlineAtMs) - Date.now());
      }
      tx.update(roomRef, {
        status: GAME_STATUS.PAUSED,
        pausedByUid: uid,
        timerRemainingMs: remaining,
        timerDeadlineAtMs: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    await logEvent(roomId, uid, 'pause', 'Игра поставлена на паузу');
    return { ok: true };
  }

  if (command === 'resume_game') {
    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);
      const room = roomSnap.data() || {};
      if (room.status !== GAME_STATUS.PAUSED) {
        return;
      }
      if (uid !== room.pausedByUid && uid !== room.hostUid) {
        throw new functions.https.HttpsError('permission-denied', 'Снимать паузу может только поставивший или ведущий');
      }
      const status = room.currentRound === 3
        ? GAME_STATUS.FINAL_ROUND
        : GAME_STATUS.IN_GAME;
      const deadline = room.timerRemainingMs
        ? Date.now() + Number(room.timerRemainingMs)
        : null;
      tx.update(roomRef, {
        status,
        pausedByUid: null,
        timerDeadlineAtMs: deadline,
        timerRemainingMs: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    await logEvent(roomId, uid, 'resume', 'Пауза снята');
    return { ok: true };
  }

  if (command === 'handle_timer_expiration') {
    await handleTimerExpirationByHost(roomRef, roomId, uid);
    return { ok: true };
  }

  throw new functions.https.HttpsError('invalid-argument', `Unknown command: ${command}`);
});

exports.serverTimerTick = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async () => {
    const now = Date.now();
    const rooms = await db
      .collection('rooms')
      .where('timerDeadlineAtMs', '<=', now)
      .where('status', '!=', GAME_STATUS.PAUSED)
      .limit(50)
      .get();

    for (const room of rooms.docs) {
      const data = room.data();
      const hostUid = data?.hostUid;
      if (!hostUid) {
        continue;
      }
      try {
        await handleTimerExpirationByHost(room.ref, room.id, hostUid);
      } catch (e) {
        console.error('timer tick failed', room.id, e.message);
      }
    }

    return null;
  });
