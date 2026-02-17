const admin = require('firebase-admin');
const functions = require('firebase-functions');

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

async function getProfile(uid) {
  const snap = await db.collection('profiles').doc(uid).get();
  return snap.data() || {};
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

async function revealFinalByHost(roomRef, roomId, hostUid) {
  await requireHost(roomRef, hostUid);
  const roomSnap = await roomRef.get();
  const room = roomSnap.data() || {};
  const finalAnswer = normalizeAnswer(room.finalAnswer || '');
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
    const answer = normalizeAnswer(player.finalAnswer || '');
    const correct = answer === finalAnswer;
    const delta = correct ? wager : -wager;

    batch.set(
      p.ref,
      {
        score: FieldValue.increment(delta),
        correctAnswers: FieldValue.increment(correct ? 1 : 0),
        wrongAnswers: FieldValue.increment(correct ? 0 : 1),
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
      score: 0,
      connected: true,
      isHost: true,
      correctAnswers: 0,
      wrongAnswers: 0,
      buzzCount: 0,
      finalWager: 0,
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

  const roomId = String(data?.roomId || payload.roomId || '');
  if (!roomId) {
    throw new functions.https.HttpsError('invalid-argument', 'roomId required');
  }

  const roomRef = db.collection('rooms').doc(roomId);

  if (command === 'join_room') {
    const profile = await getProfile(uid);
    await roomRef.collection('players').doc(uid).set(
      {
        nickname: profile.nickname || 'Игрок',
        avatarUrl: profile.avatarUrl || '',
        connected: true,
        score: FieldValue.increment(0),
        isHost: false,
        correctAnswers: FieldValue.increment(0),
        wrongAnswers: FieldValue.increment(0),
        buzzCount: FieldValue.increment(0),
        finalWager: FieldValue.increment(0),
        finalAnswer: null,
      },
      { merge: true },
    );
    await roomRef.update({ updatedAt: FieldValue.serverTimestamp() });
    await logEvent(roomId, uid, 'join', 'Игрок вошел в комнату');
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
      answer: String(payload.answer || ''),
      cost: Number(payload.cost || 100),
      round: Number(payload.round || 1),
      type: String(payload.type || 'normal'),
      used: false,
      createdBy: uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    await logEvent(roomId, uid, 'question_add', 'Добавлен вопрос');
    return { ok: true };
  }

  if (command === 'start_game') {
    await requireHost(roomRef, uid);
    await roomRef.update({
      status: GAME_STATUS.IN_GAME,
      phase: GAME_PHASE.BOARD_SELECT,
      currentRound: 1,
      chooserUid: uid,
      pausedByUid: null,
      timerDeadlineAtMs: null,
      timerRemainingMs: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
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
      .filter((p) => Number(p.data().score || 0) > 0)
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
      finalAnswer: String(payload.answer || ''),
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
      batch.set(p.ref, { finalWager: 0, finalAnswer: null }, { merge: true });
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
      timerDeadlineAtMs: Date.now() + 45000,
      timerRemainingMs: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await logEvent(roomId, uid, 'final_answers_open', 'Открыты ответы финала');
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

  if (command === 'submit_final_answer') {
    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);
      const room = roomSnap.data() || {};
      if (room.phase !== GAME_PHASE.FINAL_ANSWERING) {
        throw new functions.https.HttpsError('failed-precondition', 'Финальные ответы закрыты');
      }
      const eligible = Array.isArray(room.finalEligibleUids)
        ? room.finalEligibleUids
        : [];
      if (!eligible.includes(uid)) {
        throw new functions.https.HttpsError('permission-denied', 'Вы не участвуете в финале');
      }
      tx.set(
        roomRef.collection('players').doc(uid),
        { finalAnswer: String(payload.answer || '') },
        { merge: true },
      );
    });
    await logEvent(roomId, uid, 'final_answer', 'Ответ финала отправлен');
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
          answer: q.answer || '',
          cost: Number(q.cost || 100),
          type,
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
    const answer = String(payload.answer || '');
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
        pendingAnswer: answer,
        phase: GAME_PHASE.ANSWER_REVIEW,
        timerDeadlineAtMs: null,
        timerRemainingMs: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    await logEvent(roomId, uid, 'answer_submit', 'Игрок отправил ответ');
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
