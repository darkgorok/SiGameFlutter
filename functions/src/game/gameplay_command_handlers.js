function createGameplayCommandHandlers(deps) {
  const {
    db,
    FieldValue,
    functionsLib,
    GAME_STATUS,
    GAME_PHASE,
    PLAYER_ROLE,
    FINAL_RESULT,
    ensureVoiceRole,
    toFiniteNumber,
    getQuestionBehavior,
    getPlayerRole,
    requireHost,
    getRoundStats,
    getNextPlayableRound,
    buildFinalRoundPayload,
    revealFinalByHost,
    autoAdvanceGameFlowIfNeeded,
    handleTimerExpirationByHost,
    logEvent,
    transitions,
    withEngineStage,
    GAME_TIMER_MS,
  } = deps;

  function assertGameplayNotPaused(room) {
    if (room?.status === GAME_STATUS.PAUSED) {
      throw new functionsLib.https.HttpsError(
        'failed-precondition',
        'Game is paused',
      );
    }
  }

  function isConnectedVoicePlayer(player) {
    if (!player || typeof player !== 'object') {
      return false;
    }
    const role = player.role || PLAYER_ROLE.PLAYER;
    return Boolean(player.connected) && ensureVoiceRole(role);
  }

  function getTimerMs(room, key) {
    const custom = Number(room?.rules?.timers?.[key]);
    if (Number.isFinite(custom) && custom >= 1000) {
      return Math.floor(custom);
    }
    return Number(GAME_TIMER_MS[key] || 1000);
  }

  return {
    async start_game({ uid, roomId, roomRef }) {
      await requireHost(roomRef, uid);
      const questions = await roomRef.collection('questions').get();
      const batch = db.batch();
      questions.docs.forEach((q) => {
        const data = q.data() || {};
        const type = String(data.kind || data.type || '').trim().toLowerCase();
        if (type !== 'closest_number') {
          batch.update(q.ref, { answer: FieldValue.delete() });
        }
      });
      batch.update(
        roomRef,
        transitions.applyCommandTransition('start_game', {
          chooserUid: uid,
        }),
      );
      await batch.commit();
      await logEvent(roomId, uid, 'start', 'Ð˜Ð³Ñ€Ð° Ð·Ð°Ð¿ÑƒÑ‰ÐµÐ½Ð°');
      return { ok: true };
    },

    async advance_round2({ uid, roomId, roomRef }) {
      await requireHost(roomRef, uid);
      const roomSnap = await roomRef.get();
      const room = roomSnap.data() || {};
      assertGameplayNotPaused(room);
      const currentRound = Math.max(1, Number(room.currentRound || 1));
      const stats = await getRoundStats(roomRef);
      const nextRound = getNextPlayableRound(stats.unusedRounds, currentRound);
      if (nextRound === null) {
        throw new functionsLib.https.HttpsError(
          'failed-precondition',
          'ÐÐµÑ‚ ÑÐ»ÐµÐ´ÑƒÑŽÑ‰ÐµÐ³Ð¾ Ñ€Ð°ÑƒÐ½Ð´Ð° Ñ Ð½ÐµÑÑ‹Ð³Ñ€Ð°Ð½Ð½Ñ‹Ð¼Ð¸ Ð²Ð¾Ð¿Ñ€Ð¾ÑÐ°Ð¼Ð¸',
        );
      }
      await roomRef.update(
        transitions.applyCommandTransition('advance_round', {
          nextRound,
        }),
      );
      await logEvent(roomId, uid, 'round_next', `ÐŸÐµÑ€ÐµÑ…Ð¾Ð´ Ð² Ñ€Ð°ÑƒÐ½Ð´ ${nextRound}`);
      return { ok: true };
    },

    async start_final_round({ uid, roomId, roomRef }) {
      await requireHost(roomRef, uid);
      const roomSnap = await roomRef.get();
      const room = roomSnap.data() || {};
      assertGameplayNotPaused(room);
      const {
        eligible,
        finalRoundNumber,
        finalThemePool,
        selectedFinal,
        finalThemeDeleteOrder,
        finalThemeDeleteCandidates,
        finalThemeDeleteNeedsSelection,
        finalThemeDeleteIndex,
        finalThemeDeleteCurrentUid,
      } = await buildFinalRoundPayload(
        roomRef,
        room.currentRound,
      );
      if (eligible.length === 0) {
        throw new functionsLib.https.HttpsError(
          'failed-precondition',
          'No eligible players for final round',
        );
      }

      await roomRef.update(
        transitions.applyCommandTransition('start_final_round', {
          finalRoundNumber,
          eligible,
          finalThemePool,
          selectedFinal,
          finalThemeDeleteOrder,
          finalThemeDeleteCandidates,
          finalThemeDeleteNeedsSelection,
          finalThemeDeleteIndex,
          finalThemeDeleteCurrentUid,
        }),
      );

      await logEvent(roomId, uid, 'final_start', 'Ð—Ð°Ð¿ÑƒÑ‰ÐµÐ½ Ñ„Ð¸Ð½Ð°Ð»ÑŒÐ½Ñ‹Ð¹ Ñ€Ð°ÑƒÐ½Ð´');
      return { ok: true, eligibleCount: eligible.length };
    },

    async set_final_question({ uid, payload, roomId, roomRef }) {
      await requireHost(roomRef, uid);
      const theme = String(payload.theme || '').trim();
      const question = String(payload.question || '').trim();
      const answer = String(payload.answer || '').trim();
      if (!theme || !question || !answer) {
        throw new functionsLib.https.HttpsError(
          'invalid-argument',
          'theme, question and answer are required',
        );
      }
      const roomSnap = await roomRef.get();
      const room = roomSnap.data() || {};
      assertGameplayNotPaused(room);
      if (room.phase !== GAME_PHASE.FINAL_SETUP) {
        throw new functionsLib.https.HttpsError(
          'failed-precondition',
          'Final question can be set only during final setup',
        );
      }
      await roomRef.update(
        transitions.applyCommandTransition('set_final_question', {
          theme,
          question,
          answer,
        }),
      );
      await logEvent(roomId, uid, 'final_question_set', 'Ð¤Ð¸Ð½Ð°Ð»ÑŒÐ½Ñ‹Ð¹ Ð²Ð¾Ð¿Ñ€Ð¾Ñ Ð·Ð°Ð´Ð°Ð½');
      return { ok: true };
    },
    async select_final_theme_deleter({ uid, payload, roomId, roomRef }) {
      await requireHost(roomRef, uid);
      const targetUid = String(payload.targetUid || '').trim();
      if (!targetUid) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'targetUid required');
      }

      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        if (!roomSnap.exists) {
          throw new functionsLib.https.HttpsError('not-found', 'Room not found');
        }
        const room = roomSnap.data() || {};
        assertGameplayNotPaused(room);
        if (room.phase !== GAME_PHASE.FINAL_SETUP) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Final deleter can be selected only during final setup',
          );
        }

        const candidates = Array.isArray(room.finalThemeDeleteCandidates)
          ? room.finalThemeDeleteCandidates
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        if (!candidates.includes(targetUid)) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Target is not a valid final theme delete candidate',
          );
        }

        const order = Array.isArray(room.finalThemeDeleteOrder)
          ? room.finalThemeDeleteOrder
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        if (!order.includes(targetUid)) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Target is not in final theme delete order',
          );
        }

        tx.update(roomRef, {
          finalThemeDeleteCurrentUid: targetUid,
          finalThemeDeleteNeedsSelection: false,
          finalThemeDeleteIndex: order.indexOf(targetUid),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });

      await logEvent(roomId, uid, 'final_theme_deleter_selected', `Final deleter: ${targetUid}`);
      return { ok: true };
    },
    async delete_final_theme({ uid, payload, roomId, roomRef }) {
      const themeToDelete = String(payload.theme || '').trim();
      if (!themeToDelete) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'theme required');
      }

      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        if (!roomSnap.exists) {
          throw new functionsLib.https.HttpsError('not-found', 'Room not found');
        }
        const room = roomSnap.data() || {};
        assertGameplayNotPaused(room);
        if (room.phase !== GAME_PHASE.FINAL_SETUP) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Final theme deletion is only available during final setup',
          );
        }
        if (room.finalThemeDeleteNeedsSelection === true &&
          !String(room.finalThemeDeleteCurrentUid || '').trim()) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Select final theme deleter first',
          );
        }
        const currentDeleterUid = String(room.finalThemeDeleteCurrentUid || '').trim();
        if (uid !== room.hostUid && currentDeleterUid && uid !== currentDeleterUid) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Only current final theme deleter or host can delete a theme',
          );
        }
        if (uid !== room.hostUid) {
          const deleterRef = roomRef.collection('players').doc(uid);
          const deleterSnap = await tx.get(deleterRef);
          const deleter = deleterSnap.data() || {};
          if (!isConnectedVoicePlayer(deleter)) {
            throw new functionsLib.https.HttpsError(
              'permission-denied',
              'Disconnected final deleter cannot delete theme',
            );
          }
        }

        const pool = Array.isArray(room.finalThemePool)
          ? room.finalThemePool
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        if (!pool.includes(themeToDelete)) {
          throw new functionsLib.https.HttpsError('not-found', 'Theme not found in final pool');
        }
        if (pool.length <= 1) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Cannot delete the last final theme',
          );
        }

        const nextPool = pool.filter((theme) => theme !== themeToDelete);
        const update = {
          finalThemePool: nextPool,
          finalTheme: null,
          finalQuestion: null,
          finalAnswer: null,
          finalThemeDeleteCandidates: [],
          finalThemeDeleteNeedsSelection: false,
          finalThemeDeleteCurrentUid: null,
          updatedAt: FieldValue.serverTimestamp(),
        };

        if (nextPool.length === 1) {
          const selectedTheme = nextPool[0];
          const qSnap = await tx.get(roomRef.collection('questions'));
          let selectedQuestionDoc = qSnap.docs
            .filter((doc) => {
              const q = doc.data() || {};
              return q.used !== true && String(q.theme || '').trim() === selectedTheme;
            })
            .sort((a, b) => {
              const aq = a.data() || {};
              const bq = b.data() || {};
              const byRound = Number(bq.round || 1) - Number(aq.round || 1);
              if (byRound !== 0) {
                return byRound;
              }
              return Number(aq.cost || 0) - Number(bq.cost || 0);
            })[0];
          if (!selectedQuestionDoc) {
            selectedQuestionDoc = qSnap.docs
              .filter((doc) => {
                const q = doc.data() || {};
                return String(q.theme || '').trim() === selectedTheme;
              })
              .sort((a, b) => {
                const aq = a.data() || {};
                const bq = b.data() || {};
                const byRound = Number(bq.round || 1) - Number(aq.round || 1);
                if (byRound !== 0) {
                  return byRound;
                }
                return Number(aq.cost || 0) - Number(bq.cost || 0);
              })[0];
          }
          if (selectedQuestionDoc) {
            const q = selectedQuestionDoc.data() || {};
            update.finalTheme = selectedTheme;
            update.finalQuestion = String(q.text || '');
            update.finalAnswer = String(q.answer || '');
          } else {
            update.finalTheme = selectedTheme;
          }
        }

        if (nextPool.length > 1) {
          const order = Array.isArray(room.finalThemeDeleteOrder)
            ? room.finalThemeDeleteOrder
              .map((v) => String(v || '').trim())
              .filter((v) => v.length > 0)
            : [];
          if (order.length > 0) {
            const currentIndex = Math.max(0, Number(room.finalThemeDeleteIndex || 0));
            const nextIndex = (currentIndex + 1) % order.length;
            update.finalThemeDeleteOrder = order;
            update.finalThemeDeleteIndex = nextIndex;
            update.finalThemeDeleteCurrentUid = order[nextIndex];
          }
        } else {
          update.finalThemeDeleteCurrentUid = null;
        }

        tx.update(roomRef, update);
      });

      await logEvent(roomId, uid, 'final_theme_deleted', `Final theme removed: ${themeToDelete}`);
      return { ok: true };
    },
    async open_final_wagers({ uid, roomId, roomRef }) {
      await requireHost(roomRef, uid);
      const roomSnap = await roomRef.get();
      const room = roomSnap.data() || {};
      assertGameplayNotPaused(room);
      if (room.phase !== GAME_PHASE.FINAL_SETUP) {
        throw new functionsLib.https.HttpsError(
          'failed-precondition',
          'Final wagers can be opened only during final setup',
        );
      }
      if (!String(room.finalTheme || '').trim() || !String(room.finalQuestion || '').trim()) {
        throw new functionsLib.https.HttpsError(
          'failed-precondition',
          'Final theme and question must be selected before opening wagers',
        );
      }
      const eligible = Array.isArray(room.finalEligibleUids)
        ? room.finalEligibleUids
          .map((v) => String(v || '').trim())
          .filter((v) => v.length > 0)
        : [];
      if (eligible.length === 0) {
        throw new functionsLib.https.HttpsError(
          'failed-precondition',
          'No eligible players for final wagering',
        );
      }
      const players = await roomRef.collection('players').get();
      const batch = db.batch();
      players.docs.forEach((p) => {
        batch.set(
          p.ref,
          {
            finalWager: 0,
            finalWagerSubmitted: false,
            finalAnswerSubmitted: false,
            finalAnswerText: null,
            finalAnswerSubmittedAt: null,
            finalResult: FINAL_RESULT.PENDING,
            finalAnswer: null,
            finalRevealed: false,
          },
          { merge: true },
        );
      });
      batch.update(
        roomRef,
        {
          ...transitions.applyCommandTransition('open_final_wagers', {
            room,
            nowMs: Date.now(),
          }),
          finalAnswerOrder: [],
          finalAnswerIndex: 0,
          finalAnswerCurrentUid: null,
          finalRevealOrder: [],
          finalRevealIndex: 0,
          finalRevealCurrentUid: null,
          updatedAt: FieldValue.serverTimestamp(),
        },
      );
      await batch.commit();
      await logEvent(roomId, uid, 'final_wager_open', 'ÐžÑ‚ÐºÑ€Ñ‹Ñ‚Ñ‹ ÑÑ‚Ð°Ð²ÐºÐ¸ Ñ„Ð¸Ð½Ð°Ð»Ð°');
      return { ok: true };
    },

    async open_final_answers({ uid, roomId, roomRef }) {
      await requireHost(roomRef, uid);
      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        if (!roomSnap.exists) {
          throw new functionsLib.https.HttpsError('not-found', 'Room not found');
        }
        const room = roomSnap.data() || {};
        assertGameplayNotPaused(room);
        if (room.phase !== GAME_PHASE.FINAL_WAGERING) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Final answering can be opened only from final wagering phase',
          );
        }
        const eligible = Array.isArray(room.finalEligibleUids)
          ? room.finalEligibleUids
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        if (eligible.length === 0) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'No eligible players for final answering',
          );
        }
        const playersSnap = await tx.get(roomRef.collection('players'));
        const playersByUid = new Map(
          playersSnap.docs.map((doc) => [doc.id, doc.data() || {}]),
        );
        const allEligibleSubmitted = eligible.every(
          (playerUid) => Boolean(playersByUid.get(playerUid)?.finalWagerSubmitted) === true,
        );
        if (!allEligibleSubmitted) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Not all final wagers are submitted',
          );
        }
        const answerOrder = eligible
          .map((playerUid) => ({
            uid: playerUid,
            score: Number(playersByUid.get(playerUid)?.score || 0),
          }))
          .sort((a, b) => (a.score - b.score) || a.uid.localeCompare(b.uid))
          .map((entry) => entry.uid);
        const currentUid = answerOrder.length > 0 ? answerOrder[0] : null;
        for (const playerUid of eligible) {
          tx.set(
            roomRef.collection('players').doc(playerUid),
            {
              finalAnswerSubmitted: false,
              finalAnswerText: null,
              finalAnswerSubmittedAt: null,
            },
            { merge: true },
          );
        }
        tx.update(roomRef, {
          ...transitions.applyCommandTransition('open_final_answers', {
            room,
            nowMs: Date.now(),
          }),
          finalAnswerOrder: answerOrder,
          finalAnswerIndex: 0,
          finalAnswerCurrentUid: currentUid,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      await logEvent(roomId, uid, 'final_answers_open', 'Final answers stage opened');
      return { ok: true };
    },

    async submit_final_answer({ uid, payload, roomId, roomRef }) {
      const answer = String(payload.answer || '').trim();
      if (!answer) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'answer required');
      }

      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        if (!roomSnap.exists) {
          throw new functionsLib.https.HttpsError('not-found', 'Room not found');
        }
        const room = roomSnap.data() || {};
        assertGameplayNotPaused(room);
        if (room.phase !== GAME_PHASE.FINAL_ANSWERING) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Final answering stage is not active',
          );
        }
        const eligible = Array.isArray(room.finalEligibleUids)
          ? room.finalEligibleUids
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        if (!eligible.includes(uid)) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Player is not eligible for final answering',
          );
        }
        const currentUid = String(room.finalAnswerCurrentUid || '').trim();
        if (currentUid && currentUid !== uid) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'It is not this player turn to answer now',
          );
        }
        const playerRef = roomRef.collection('players').doc(uid);
        const playerSnap = await tx.get(playerRef);
        const player = playerSnap.data() || {};
        if (!isConnectedVoicePlayer(player)) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Player is disconnected from final answering',
          );
        }
        if (Boolean(player.finalAnswerSubmitted)) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Final answer has already been submitted',
          );
        }

        tx.set(
          playerRef,
          {
            finalAnswerSubmitted: true,
            finalAnswerText: answer,
            finalAnswerSubmittedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      });

      await logEvent(roomId, uid, 'final_answer_submit', 'Final answer submitted');
      return { ok: true };
    },

    async submit_final_wager({ uid, payload, roomId, roomRef }) {
      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        if (!roomSnap.exists) {
          throw new functionsLib.https.HttpsError('not-found', 'Room not found');
        }
        const room = roomSnap.data();
        assertGameplayNotPaused(room);
        if (room.phase !== GAME_PHASE.FINAL_WAGERING) {
          throw new functionsLib.https.HttpsError('failed-precondition', 'Ð¡Ñ‚Ð°Ð²ÐºÐ¸ ÑÐµÐ¹Ñ‡Ð°Ñ Ð·Ð°ÐºÑ€Ñ‹Ñ‚Ñ‹');
        }
        const eligible = Array.isArray(room.finalEligibleUids)
          ? room.finalEligibleUids
          : [];
        if (!eligible.includes(uid)) {
          throw new functionsLib.https.HttpsError('permission-denied', 'Ð’Ñ‹ Ð½Ðµ ÑƒÑ‡Ð°ÑÑ‚Ð²ÑƒÐµÑ‚Ðµ Ð² Ñ„Ð¸Ð½Ð°Ð»Ðµ');
        }
        const playerRef = roomRef.collection('players').doc(uid);
        const playerSnap = await tx.get(playerRef);
        const player = playerSnap.data() || {};
        if (!isConnectedVoicePlayer(player)) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Player is disconnected from final wagering',
          );
        }
        if (Boolean(player.finalWagerSubmitted)) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Final wager has already been submitted',
          );
        }
        const score = Number(player.score || 0);
        const wager = Number(payload.wager || 0);
        const maxWager = Math.max(score, 0);
        if (maxWager > 0 && wager <= 0) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Final wager must be greater than 0 for positive score',
          );
        }
        const safeWager = Math.max(0, Math.min(wager, maxWager));
        tx.set(
          playerRef,
          {
            finalWager: safeWager,
            finalWagerSubmitted: true,
          },
          { merge: true },
        );
      });
      await logEvent(roomId, uid, 'final_wager', 'Ð¡Ñ‚Ð°Ð²ÐºÐ° Ñ„Ð¸Ð½Ð°Ð»Ð° Ð¾Ñ‚Ð¿Ñ€Ð°Ð²Ð»ÐµÐ½Ð°');
      return { ok: true };
    },

    async set_final_player_result({ uid, payload, roomId, roomRef }) {
      const targetUid = String(payload.targetUid || '');
      const result = String(payload.result || FINAL_RESULT.PENDING);
      const normalized = [
        FINAL_RESULT.CORRECT,
        FINAL_RESULT.WRONG,
        FINAL_RESULT.NO_ANSWER,
      ].includes(result)
        ? result
        : null;
      await requireHost(roomRef, uid);
      if (!normalized) {
        throw new functionsLib.https.HttpsError(
          'invalid-argument',
          'result must be correct, wrong or no_answer',
        );
      }
      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        if (!roomSnap.exists) {
          throw new functionsLib.https.HttpsError('not-found', 'Room not found');
        }
        const room = roomSnap.data() || {};
        assertGameplayNotPaused(room);
        if (room.phase !== GAME_PHASE.FINAL_ANSWERING) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Final answering stage is not active',
          );
        }
        if (!targetUid) {
          throw new functionsLib.https.HttpsError('invalid-argument', 'targetUid required');
        }
        const eligible = Array.isArray(room.finalEligibleUids)
          ? room.finalEligibleUids
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        if (!eligible.includes(targetUid)) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Player is not eligible for final',
          );
        }
        const order = Array.isArray(room.finalAnswerOrder)
          ? room.finalAnswerOrder
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        const fallbackOrder = order.length > 0 ? order : [...eligible].sort((a, b) => a.localeCompare(b));
        const currentUid = String(room.finalAnswerCurrentUid || '').trim() ||
          fallbackOrder[Math.max(0, Number(room.finalAnswerIndex || 0))] ||
          '';
        if (currentUid && targetUid !== currentUid) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Only current final answering player can be marked now',
          );
        }
        const playersSnap = await tx.get(roomRef.collection('players'));
        const resultByUid = new Map();
        playersSnap.docs.forEach((doc) => {
          resultByUid.set(doc.id, String(doc.data()?.finalResult || FINAL_RESULT.PENDING));
        });
        resultByUid.set(targetUid, normalized);
        let nextIndex = fallbackOrder.length;
        let nextUid = null;
        for (let i = 0; i < fallbackOrder.length; i += 1) {
          const candidateUid = fallbackOrder[i];
          const candidateResult = String(resultByUid.get(candidateUid) || FINAL_RESULT.PENDING);
          if (candidateResult === FINAL_RESULT.PENDING) {
            nextIndex = i;
            nextUid = candidateUid;
            break;
          }
        }
        tx.set(
          roomRef.collection('players').doc(targetUid),
          { finalResult: normalized },
          { merge: true },
        );
        tx.update(roomRef, {
          finalAnswerOrder: fallbackOrder,
          finalAnswerIndex: nextIndex,
          finalAnswerCurrentUid: nextUid,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      await logEvent(roomId, uid, 'final_mark', 'Final answer result updated');
      return { ok: true };
    },

    async reveal_final({ uid, roomId, roomRef }) {
      const roomSnap = await roomRef.get();
      const room = roomSnap.data() || {};
      assertGameplayNotPaused(room);
      await revealFinalByHost(roomRef, roomId, uid);
      return { ok: true };
    },

    async pick_question({ uid, payload, roomId, roomRef }) {
      const questionId = String(payload.questionId || '');
      if (!questionId) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'questionId required');
      }

      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        if (!roomSnap.exists) {
          throw new functionsLib.https.HttpsError('not-found', 'Room not found');
        }
        const room = roomSnap.data();
        assertGameplayNotPaused(room);
        const qRef = roomRef.collection('questions').doc(questionId);
        const qSnap = await tx.get(qRef);
        if (!qSnap.exists) {
          throw new functionsLib.https.HttpsError('not-found', 'Question not found');
        }
        const q = qSnap.data();

        if (room.status === GAME_STATUS.PAUSED) {
          throw new functionsLib.https.HttpsError('failed-precondition', 'Ð˜Ð³Ñ€Ð° Ð½Ð° Ð¿Ð°ÑƒÐ·Ðµ');
        }
        if (room.phase !== GAME_PHASE.BOARD_SELECT) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'ÐÐµÐ»ÑŒÐ·Ñ Ð²Ñ‹Ð±Ñ€Ð°Ñ‚ÑŒ Ð²Ð¾Ð¿Ñ€Ð¾Ñ ÑÐµÐ¹Ñ‡Ð°Ñ',
          );
        }
        if (room.chooserUid !== uid && room.hostUid !== uid) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Ð¡ÐµÐ¹Ñ‡Ð°Ñ Ð²Ñ‹Ð±Ð¾Ñ€ Ñƒ Ð´Ñ€ÑƒÐ³Ð¾Ð³Ð¾ Ð¸Ð³Ñ€Ð¾ÐºÐ°',
          );
        }
        if (uid !== room.hostUid) {
          const chooserRef = roomRef.collection('players').doc(uid);
          const chooserSnap = await tx.get(chooserRef);
          const chooser = chooserSnap.data() || {};
          if (!isConnectedVoicePlayer(chooser)) {
            throw new functionsLib.https.HttpsError(
              'permission-denied',
              'Disconnected chooser cannot pick question',
            );
          }
        }
        if (q.used === true) {
          throw new functionsLib.https.HttpsError('failed-precondition', 'Ð’Ð¾Ð¿Ñ€Ð¾Ñ ÑƒÐ¶Ðµ ÑÑ‹Ð³Ñ€Ð°Ð½');
        }
        const questionRound = Math.max(1, Number(q.round || 1));
        const activeRound = Math.max(1, Number(room.currentRound || 1));
        if (questionRound !== activeRound) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'ÐÐµÐ»ÑŒÐ·Ñ Ð²Ñ‹Ð±Ñ€Ð°Ñ‚ÑŒ Ð²Ð¾Ð¿Ñ€Ð¾Ñ Ð¸Ð· Ð´Ñ€ÑƒÐ³Ð¾Ð³Ð¾ Ñ€Ð°ÑƒÐ½Ð´Ð°',
          );
        }

        const behavior = getQuestionBehavior(q.kind || q.type);
        const nowMs = Date.now();
        tx.update(qRef, { used: true });

        if (behavior.autoResolveWithoutAnswer) {
          const amount = Number(q.cost || 0);
          const chooserUid = String(room.chooserUid || uid).trim() || uid;
          tx.set(
            roomRef.collection('players').doc(chooserUid),
            {
              score: FieldValue.increment(amount),
              correctAnswers: FieldValue.increment(1),
            },
            { merge: true },
          );
          tx.update(
            roomRef,
            transitions.applyCommandTransition('judge_correct', {
              roomStatus: room.status,
              playerUid: chooserUid,
            }),
          );
          return;
        }

        tx.update(
          roomRef,
          transitions.applyCommandTransition('pick_question', {
            roomStatus: room.status,
            room,
            chooserUid: String(room.chooserUid || uid || '').trim() || null,
            questionId,
            question: q,
            nowMs,
          }),
        );
      });

      await logEvent(roomId, uid, 'question_pick', 'Ð’Ñ‹Ð±Ñ€Ð°Ð½ Ð²Ð¾Ð¿Ñ€Ð¾Ñ');
      return { ok: true };
    },

    async open_buzzing({ uid, roomId, roomRef }) {
      await db.runTransaction(async (tx) => {
        const roomSnap = await requireHost(roomRef, uid, tx);
        const room = roomSnap.data();
        assertGameplayNotPaused(room);
        if (room.phase !== GAME_PHASE.QUESTION_REVEAL) {
          throw new functionsLib.https.HttpsError('failed-precondition', 'ÐÐµÐ²ÐµÑ€Ð½Ñ‹Ð¹ ÑÑ‚Ð°Ð¿');
        }
        tx.update(
          roomRef,
          transitions.applyCommandTransition('open_buzzing', {
            roomStatus: room.status,
            room,
            nowMs: Date.now(),
          }),
        );
      });
      await logEvent(roomId, uid, 'buzz_open', 'ÐžÑ‚ÐºÑ€Ñ‹Ñ‚Ð° ÐºÐ½Ð¾Ð¿ÐºÐ° Ð¾Ñ‚Ð²ÐµÑ‚Ð°');
      return { ok: true };
    },

    async select_cat_target({ uid, payload, roomId, roomRef }) {
      const targetUid = String(payload.targetUid || '');
      if (!targetUid) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'targetUid required');
      }
      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        if (!roomSnap.exists) {
          throw new functionsLib.https.HttpsError('not-found', 'Room not found');
        }
        const room = roomSnap.data();
        assertGameplayNotPaused(room);
        if (room.phase !== GAME_PHASE.CAT_TARGETING) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Ð¡ÐµÐ¹Ñ‡Ð°Ñ Ð½Ðµ ÑÑ‚Ð°Ð¿ ÐºÐ¾Ñ‚Ð° Ð² Ð¼ÐµÑˆÐºÐµ',
          );
        }
        if (room.chooserUid !== uid && room.hostUid !== uid) {
          throw new functionsLib.https.HttpsError('permission-denied', 'ÐÐµÑ‚ Ð¿Ñ€Ð°Ð² Ð²Ñ‹Ð±Ñ€Ð°Ñ‚ÑŒ Ð¸Ð³Ñ€Ð¾ÐºÐ°');
        }
        if (uid !== room.hostUid) {
          const chooserRef = roomRef.collection('players').doc(uid);
          const chooserSnap = await tx.get(chooserRef);
          const chooser = chooserSnap.data() || {};
          if (!isConnectedVoicePlayer(chooser)) {
            throw new functionsLib.https.HttpsError(
              'permission-denied',
              'Disconnected chooser cannot select cat target',
            );
          }
        }
        const targetRef = roomRef.collection('players').doc(targetUid);
        const targetSnap = await tx.get(targetRef);
        const targetPlayer = targetSnap.data() || {};
        if (!isConnectedVoicePlayer(targetPlayer)) {
          throw new functionsLib.https.HttpsError('failed-precondition', 'ÐÐµÐ»ÑŒÐ·Ñ Ð²Ñ‹Ð±Ñ€Ð°Ñ‚ÑŒ Ð·Ñ€Ð¸Ñ‚ÐµÐ»Ñ');
        }
        tx.update(
          roomRef,
          transitions.applyCommandTransition('select_cat_target', {
            roomStatus: room.status,
            room,
            targetUid,
            nowMs: Date.now(),
          }),
        );
        tx.set(
          roomRef.collection('players').doc(targetUid),
          { buzzCount: FieldValue.increment(1) },
          { merge: true },
        );
      });
      await logEvent(roomId, uid, 'cat_target', 'ÐšÐ¾Ñ‚ Ð² Ð¼ÐµÑˆÐºÐµ Ð¿ÐµÑ€ÐµÐ´Ð°Ð½ Ð¸Ð³Ñ€Ð¾ÐºÑƒ');
      return { ok: true };
    },

    async set_wager_and_open({ uid, payload, roomId, roomRef }) {
      const wager = Number(payload.wager || 100);
      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        const room = roomSnap.data() || {};
        assertGameplayNotPaused(room);
        if (room.phase !== GAME_PHASE.WAGER_BIDDING) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Ð¡Ñ‚Ð°Ð²ÐºÐ° Ð½ÐµÐ´Ð¾ÑÑ‚ÑƒÐ¿Ð½Ð° ÑÐµÐ¹Ñ‡Ð°Ñ',
          );
        }
        const behavior = getQuestionBehavior(
          room.activeQuestion?.kind || room.activeQuestion?.type,
        );
        const isStake = behavior.kind === 'stake';
        if (!isStake && uid !== room.hostUid && uid !== room.chooserUid) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Only chooser or host can set auction wager',
          );
        }
        let actorUid = room.chooserUid || uid;
        if (isStake) {
          if (uid === room.hostUid) {
            const requestedTargetUid = String(payload.targetUid || '').trim();
            actorUid = requestedTargetUid || actorUid;
          } else {
            actorUid = uid;
          }
        }
        const actorRef = roomRef.collection('players').doc(actorUid);
        const actorSnap = await tx.get(actorRef);
        const actor = actorSnap.data() || {};
        if (!isConnectedVoicePlayer(actor)) {
          throw new functionsLib.https.HttpsError('permission-denied', 'Viewer cannot set wager');
        }
        const score = Number(actor.score || 0);
        const maxWager = score > 0 ? score : Number(room.activeQuestion?.cost || 100);
        const minWager = maxWager >= 100 ? 100 : 0;
        const safeWager = Math.max(minWager, Math.min(wager, maxWager));

        tx.update(
          roomRef,
          transitions.applyCommandTransition('set_wager_and_open', {
            roomStatus: room.status,
            room,
            actorUid,
            safeWager,
            nowMs: Date.now(),
          }),
        );
        tx.set(actorRef, { buzzCount: FieldValue.increment(1) }, { merge: true });
      });
      await logEvent(roomId, uid, 'wager_set', 'Ð£ÑÑ‚Ð°Ð½Ð¾Ð²Ð»ÐµÐ½Ð° ÑÑ‚Ð°Ð²ÐºÐ° Ð°ÑƒÐºÑ†Ð¸Ð¾Ð½Ð°');
      return { ok: true };
    },

    async buzz({ uid, roomId, roomRef }) {
      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        const room = roomSnap.data() || {};
        assertGameplayNotPaused(room);

        const falseStartEnabled = room?.rules?.falseStartEnabled === true;
        const canFalseStart = falseStartEnabled && room.phase === GAME_PHASE.QUESTION_REVEAL;
        if ((room.phase !== GAME_PHASE.ANSWERING && !canFalseStart) || room.status === GAME_STATUS.PAUSED) {
          throw new functionsLib.https.HttpsError('failed-precondition', 'ÐšÐ½Ð¾Ð¿ÐºÐ° ÑÐµÐ¹Ñ‡Ð°Ñ Ð·Ð°ÐºÑ€Ñ‹Ñ‚Ð°');
        }
        const playerRef = roomRef.collection('players').doc(uid);
        const playerSnap = await tx.get(playerRef);
        const player = playerSnap.data() || {};
        if (!isConnectedVoicePlayer(player)) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Ð—Ñ€Ð¸Ñ‚ÐµÐ»ÑŒ Ð½Ðµ ÑƒÑ‡Ð°ÑÑ‚Ð²ÑƒÐµÑ‚ Ð² Ð¾Ñ‚Ð²ÐµÑ‚Ð°Ñ…',
          );
        }
        if (room.currentAttemptUid) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Ð¡ÐµÐ¹Ñ‡Ð°Ñ ÑƒÐ¶Ðµ ÐµÑÑ‚ÑŒ Ð¾Ñ‚Ð²ÐµÑ‡Ð°ÑŽÑ‰Ð¸Ð¹ Ð¸Ð³Ñ€Ð¾Ðº',
          );
        }
        if (Number(room.pressBlockedUntilMs || 0) > Date.now()) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Button is temporarily blocked',
          );
        }
        if (room.targetedUid && room.targetedUid !== uid) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Ð­Ñ‚Ð¾ Ð²Ð¾Ð¿Ñ€Ð¾Ñ Ð´Ð»Ñ Ð´Ñ€ÑƒÐ³Ð¾Ð³Ð¾ Ð¸Ð³Ñ€Ð¾ÐºÐ°',
          );
        }
        const queue = Array.isArray(room.buzzQueue) ? [...room.buzzQueue] : [];
        if (queue.includes(uid)) {
          throw new functionsLib.https.HttpsError('failed-precondition', 'Ð’Ñ‹ ÑƒÐ¶Ðµ Ð² Ð¾Ñ‡ÐµÑ€ÐµÐ´Ð¸');
        }
        queue.push(uid);
        tx.update(roomRef, {
          buzzQueue: queue,
          currentAttemptUid: uid,
          ...(canFalseStart ? { phase: GAME_PHASE.ANSWERING } : {}),
          timerDeadlineAtMs: Date.now() + getTimerMs(room, 'ANSWERING'),
          timerRemainingMs: null,
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.set(
          roomRef.collection('players').doc(uid),
          { buzzCount: FieldValue.increment(1) },
          { merge: true },
        );
      });
      await logEvent(roomId, uid, 'buzz', 'Ð˜Ð³Ñ€Ð¾Ðº Ð½Ð°Ð¶Ð°Ð» ÐºÐ½Ð¾Ð¿ÐºÑƒ');
      return { ok: true };
    },

    async submit_answer({ uid, roomId, roomRef }) {
      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        const room = roomSnap.data() || {};
        assertGameplayNotPaused(room);
        if (room.phase !== GAME_PHASE.ANSWERING) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'ÐÐµÐ»ÑŒÐ·Ñ Ð¾Ñ‚Ð¿Ñ€Ð°Ð²Ð¸Ñ‚ÑŒ Ð¾Ñ‚Ð²ÐµÑ‚ Ð½Ð° ÑÑ‚Ð¾Ð¼ ÑÑ‚Ð°Ð¿Ðµ',
          );
        }

        const behavior = getQuestionBehavior(
          room.activeQuestion?.kind || room.activeQuestion?.type,
        );
        const forAllMode = room.forAllMode === true || behavior.isForAll;
        const playerRef = roomRef.collection('players').doc(uid);
        const playerSnap = await tx.get(playerRef);
        const player = playerSnap.data() || {};
        if (!isConnectedVoicePlayer(player)) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Viewer cannot answer',
          );
        }

        if (forAllMode) {
          const playersSnap = await tx.get(roomRef.collection('players'));
          const connectedVoiceUids = playersSnap.docs
            .filter((doc) => isConnectedVoicePlayer(doc.data()))
            .map((doc) => doc.id);
          const submitted = Array.isArray(room.forAllSubmittedUids)
            ? room.forAllSubmittedUids
              .map((value) => String(value || '').trim())
              .filter((value) => value.length > 0 && connectedVoiceUids.includes(value))
            : [];
          if (submitted.includes(uid)) {
            throw new functionsLib.https.HttpsError(
              'failed-precondition',
              'ÐžÑ‚Ð²ÐµÑ‚ ÑƒÐ¶Ðµ Ð¾Ñ‚Ð¿Ñ€Ð°Ð²Ð»ÐµÐ½',
            );
          }
          const nextSubmitted = [...submitted, uid];
          const allSubmitted = connectedVoiceUids.every(
            (value) => nextSubmitted.includes(value),
          );
          if (allSubmitted) {
            const reviewOrder = connectedVoiceUids.filter((value) => nextSubmitted.includes(value));
            tx.update(
              roomRef,
              withEngineStage(
                {
                  phase: GAME_PHASE.ANSWER_REVIEW,
                  forAllMode: true,
                  forAllSubmittedUids: nextSubmitted,
                  forAllReviewOrder: reviewOrder,
                  forAllReviewIndex: 0,
                  currentAttemptUid: reviewOrder[0] || null,
                  pendingAnswer: '[voice]',
                  timerDeadlineAtMs: Date.now() + getTimerMs(room, 'ANSWER_REVIEW'),
                  timerRemainingMs: null,
                  pressBlockedUntilMs: null,
                  updatedAt: FieldValue.serverTimestamp(),
                },
                { phase: GAME_PHASE.ANSWER_REVIEW, status: room.status },
              ),
            );
          } else {
            tx.update(roomRef, {
              forAllMode: true,
              forAllSubmittedUids: nextSubmitted,
              updatedAt: FieldValue.serverTimestamp(),
            });
          }
          return;
        }

        if (room.currentAttemptUid !== uid) {
          throw new functionsLib.https.HttpsError('permission-denied', 'Ð¡ÐµÐ¹Ñ‡Ð°Ñ Ð¾Ñ‚Ð²ÐµÑ‡Ð°ÐµÑ‚ Ð´Ñ€ÑƒÐ³Ð¾Ð¹ Ð¸Ð³Ñ€Ð¾Ðº');
        }
        tx.update(
          roomRef,
          transitions.applyCommandTransition('submit_answer', {
            roomStatus: room.status,
            room,
          }),
        );
      });
      await logEvent(roomId, uid, 'answer_submit', 'Ð˜Ð³Ñ€Ð¾Ðº Ð´Ð°Ð» Ð³Ð¾Ð»Ð¾ÑÐ¾Ð²Ð¾Ð¹ Ð¾Ñ‚Ð²ÐµÑ‚');
      return { ok: true };
    },
    async submit_numeric_answer({ uid, payload, roomId, roomRef }) {
      const value = toFiniteNumber(payload.value);
      if (value === null) {
        throw new functionsLib.https.HttpsError(
          'invalid-argument',
          'value must be a finite number',
        );
      }

      let resolvedNow = false;
      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        const room = roomSnap.data() || {};
        assertGameplayNotPaused(room);
        if (room.phase !== GAME_PHASE.ANSWERING) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Нельзя отправить ответ на этом этапе',
          );
        }
        if (room.activeQuestion?.type !== 'closest_number') {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Этот вопрос не требует числового ответа',
          );
        }
        const playerRef = roomRef.collection('players').doc(uid);
        const playerSnap = await tx.get(playerRef);
        const player = playerSnap.data() || {};
        if (!isConnectedVoicePlayer(player)) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Зритель не участвует в ответах',
          );
        }

        const existing = room.numericAnswers && typeof room.numericAnswers === 'object'
          ? room.numericAnswers
          : {};
        if (Object.prototype.hasOwnProperty.call(existing, uid)) {
          throw new functionsLib.https.HttpsError('failed-precondition', 'Ответ уже отправлен');
        }

        const playersSnap = await tx.get(roomRef.collection('players'));
        const connectedVoiceUids = playersSnap.docs
          .filter((doc) => isConnectedVoicePlayer(doc.data()))
          .map((doc) => doc.id);
        const participantUids = connectedVoiceUids.filter((playerUid) => playerUid !== room.hostUid);
        const answerUids = participantUids.length > 0 ? participantUids : connectedVoiceUids;

        const nextAnswers = {
          ...existing,
          [uid]: value,
        };
        const allSubmitted = answerUids.length > 0
          && answerUids.every((playerUid) => {
            const raw = nextAnswers[playerUid];
            return toFiniteNumber(raw) !== null;
          });

        if (!allSubmitted) {
          tx.update(roomRef, {
            [`numericAnswers.${uid}`]: value,
            updatedAt: FieldValue.serverTimestamp(),
          });
          return;
        }

        const activeAnswerRaw = room.activeQuestion?.answer;
        let target = (typeof activeAnswerRaw === 'string' && activeAnswerRaw.trim() === '')
          ? null
          : toFiniteNumber(activeAnswerRaw);
        if (target === null) {
          const questionId = String(room.currentQuestionId || room.activeQuestion?.id || '').trim();
          if (questionId) {
            const questionSnap = await tx.get(roomRef.collection('questions').doc(questionId));
            const question = questionSnap.data() || {};
            target = toFiniteNumber(question.answer);
          }
        }
        if (target === null) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Correct answer is not a finite number',
          );
        }

        const amount = Number(room.wagerValue || room.activeQuestion?.cost || 0);
        let bestDistance = Number.POSITIVE_INFINITY;
        let winnerUids = [];
        answerUids.forEach((playerUid) => {
          const answerValue = toFiniteNumber(nextAnswers[playerUid]);
          if (answerValue === null) {
            return;
          }
          const distance = Math.abs(target - answerValue);
          if (distance < bestDistance) {
            bestDistance = distance;
            winnerUids = [playerUid];
            return;
          }
          if (distance === bestDistance) {
            winnerUids.push(playerUid);
          }
        });

        const exactWin = bestDistance === 0;
        const winnerDelta = exactWin ? amount * 2 : amount;
        winnerUids.forEach((playerUid) => {
          tx.set(
            roomRef.collection('players').doc(playerUid),
            {
              score: FieldValue.increment(winnerDelta),
              correctAnswers: FieldValue.increment(1),
            },
            { merge: true },
          );
        });

        tx.update(
          roomRef,
          transitions.applyCommandTransition('judge_correct', {
            roomStatus: room.status,
            playerUid: winnerUids[0] || uid,
          }),
        );
        resolvedNow = true;
      });

      if (resolvedNow) {
        await autoAdvanceGameFlowIfNeeded(roomRef);
      }
      await logEvent(roomId, uid, 'answer_submit_numeric', 'Игрок отправил числовой ответ');
      return { ok: true };
    },

    async judge_answer({ uid, payload, roomId, roomRef }) {
      const correct = !!payload.correct;

      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        const room = roomSnap.data() || {};
        assertGameplayNotPaused(room);
        if (room.hostUid !== uid) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Ð¢Ð¾Ð»ÑŒÐºÐ¾ Ð²ÐµÐ´ÑƒÑ‰Ð¸Ð¹ Ð¿Ñ€Ð¸Ð½Ð¸Ð¼Ð°ÐµÑ‚ Ð¾Ñ‚Ð²ÐµÑ‚',
          );
        }
        if (room.phase !== GAME_PHASE.ANSWER_REVIEW || !room.activeQuestion) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Ð¡ÐµÐ¹Ñ‡Ð°Ñ Ð½ÐµÑ‡ÐµÐ³Ð¾ Ð¾Ñ†ÐµÐ½Ð¸Ð²Ð°Ñ‚ÑŒ',
          );
        }
        const playerUid = room.currentAttemptUid;
        if (!playerUid) {
          throw new functionsLib.https.HttpsError('failed-precondition', 'ÐÐµ Ð¾Ð¿Ñ€ÐµÐ´ÐµÐ»Ñ‘Ð½ Ð¸Ð³Ñ€Ð¾Ðº Ð¾Ñ‚Ð²ÐµÑ‚Ð°');
        }

        const amount = Number(room.wagerValue || room.activeQuestion.cost || 0);
        const playerRef = roomRef.collection('players').doc(playerUid);
        const attempted = Array.isArray(room.buzzQueue) ? [...room.buzzQueue] : [];
        if (!attempted.includes(playerUid)) {
          attempted.push(playerUid);
        }
        const behavior = getQuestionBehavior(
          room.activeQuestion.kind || room.activeQuestion.type,
        );
        const oneShot = behavior.oneShot;
        const wrongPenalty = behavior.isNoRisk ? 0 : amount;
        const forAllMode = room.forAllMode === true || behavior.isForAll;
        const appealsEnabled = room?.rules?.useAppeals === true && !forAllMode;
        let hasRemaining = false;
        if (!forAllMode) {
          const playersSnap = await tx.get(roomRef.collection('players'));
          hasRemaining = playersSnap.docs.some((doc) => {
            return isConnectedVoicePlayer(doc.data()) && !attempted.includes(doc.id);
          });
        }

        if (!(appealsEnabled && !correct)) {
          tx.set(
            playerRef,
            {
              score: FieldValue.increment(correct ? amount : -wrongPenalty),
              correctAnswers: FieldValue.increment(correct ? 1 : 0),
              wrongAnswers: FieldValue.increment(correct ? 0 : 1),
            },
            { merge: true },
          );
        }

        if (forAllMode) {
          const reviewOrder = Array.isArray(room.forAllReviewOrder)
            ? room.forAllReviewOrder
              .map((v) => String(v || '').trim())
              .filter((v) => v.length > 0)
            : [];
          const index = Math.max(0, Number(room.forAllReviewIndex || 0));
          const nextIndex = index + 1;
          const nextUid = reviewOrder[nextIndex] || null;
          if (nextUid) {
            tx.update(
              roomRef,
              withEngineStage(
                {
                  phase: GAME_PHASE.ANSWER_REVIEW,
                  forAllMode: true,
                  forAllReviewOrder: reviewOrder,
                  forAllReviewIndex: nextIndex,
                  currentAttemptUid: nextUid,
                  pendingAnswer: '[voice]',
                  appealActive: false,
                  appealRequestedByUid: null,
                  appealForUid: null,
                  timerDeadlineAtMs: Date.now() + getTimerMs(room, 'ANSWER_REVIEW'),
                  timerRemainingMs: null,
                  pressBlockedUntilMs: null,
                  updatedAt: FieldValue.serverTimestamp(),
                },
                { phase: GAME_PHASE.ANSWER_REVIEW, status: room.status },
              ),
            );
          } else {
            tx.update(
              roomRef,
              transitions.applyCommandTransition('judge_wrong_end', {
                roomStatus: room.status,
              }),
            );
          }
          return;
        }

        if (!correct && appealsEnabled) {
          tx.update(
            roomRef,
            withEngineStage(
              {
                phase: GAME_PHASE.ANSWER_REVIEW,
                appealActive: true,
                appealRequestedByUid: null,
                appealForUid: playerUid,
                timerDeadlineAtMs: Date.now() + getTimerMs(room, 'ANSWER_REVIEW'),
                timerRemainingMs: null,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.ANSWER_REVIEW, status: room.status },
            ),
          );
          return;
        }

        if (correct) {
          tx.update(
            roomRef,
            transitions.applyCommandTransition('judge_correct', {
              roomStatus: room.status,
              playerUid,
            }),
          );
        } else if (oneShot || !hasRemaining) {
          tx.update(
            roomRef,
            transitions.applyCommandTransition('judge_wrong_end', {
              roomStatus: room.status,
            }),
          );
        } else {
          tx.update(
            roomRef,
            transitions.applyCommandTransition('judge_wrong_reopen', {
              roomStatus: room.status,
              room,
              attempted,
              nowMs: Date.now(),
            }),
          );
        }
      });

      await autoAdvanceGameFlowIfNeeded(roomRef);
      await logEvent(roomId, uid, 'judge', correct ? 'ÐžÑ‚Ð²ÐµÑ‚ Ð·Ð°ÑÑ‡Ð¸Ñ‚Ð°Ð½' : 'ÐžÑ‚Ð²ÐµÑ‚ Ð¾Ñ‚ÐºÐ»Ð¾Ð½ÐµÐ½');
      return { ok: true };
    },

    async submit_appeal({ uid, roomId, roomRef }) {
      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        const room = roomSnap.data() || {};
        assertGameplayNotPaused(room);
        if (room.phase !== GAME_PHASE.ANSWER_REVIEW || room.appealActive !== true) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'No active appeal window',
          );
        }
        if (room?.rules?.useAppeals !== true) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Appeals are disabled in room rules',
          );
        }
        if (room.hostUid === uid) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Host cannot submit appeal',
          );
        }
        if (String(room.appealForUid || '') === uid) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Answering player cannot submit appeal',
          );
        }
        if (String(room.appealRequestedByUid || '').trim()) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Appeal already submitted',
          );
        }
        const playerRef = roomRef.collection('players').doc(uid);
        const playerSnap = await tx.get(playerRef);
        const player = playerSnap.data() || {};
        if (!isConnectedVoicePlayer(player)) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Viewer cannot appeal',
          );
        }
        tx.update(roomRef, {
          appealRequestedByUid: uid,
          timerDeadlineAtMs: Date.now() + getTimerMs(room, 'ANSWER_REVIEW'),
          timerRemainingMs: null,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      await logEvent(roomId, uid, 'appeal_submit', 'Appeal submitted');
      return { ok: true };
    },

    async resolve_appeal({ uid, payload, roomId, roomRef }) {
      const accepted = payload.accepted === true || payload.correct === true;
      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        const room = roomSnap.data() || {};
        assertGameplayNotPaused(room);
        if (room.hostUid !== uid) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Only host can resolve appeal',
          );
        }
        if (room.phase !== GAME_PHASE.ANSWER_REVIEW || room.appealActive !== true) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'No active appeal to resolve',
          );
        }
        const playerUid = String(room.appealForUid || room.currentAttemptUid || '').trim();
        if (!playerUid || !room.activeQuestion) {
          throw new functionsLib.https.HttpsError(
            'failed-precondition',
            'Appeal context is invalid',
          );
        }

        const amount = Number(room.wagerValue || room.activeQuestion.cost || 0);
        const behavior = getQuestionBehavior(
          room.activeQuestion.kind || room.activeQuestion.type,
        );
        const wrongPenalty = behavior.isNoRisk ? 0 : amount;
        const attempted = Array.isArray(room.buzzQueue) ? [...room.buzzQueue] : [];
        if (!attempted.includes(playerUid)) {
          attempted.push(playerUid);
        }
        const oneShot = behavior.oneShot;
        const playersSnap = await tx.get(roomRef.collection('players'));
        const hasRemaining = playersSnap.docs.some((doc) => {
          return isConnectedVoicePlayer(doc.data()) && !attempted.includes(doc.id);
        });

        if (accepted) {
          tx.set(
            roomRef.collection('players').doc(playerUid),
            {
              score: FieldValue.increment(amount),
              correctAnswers: FieldValue.increment(1),
            },
            { merge: true },
          );
          tx.update(
            roomRef,
            transitions.applyCommandTransition('judge_correct', {
              roomStatus: room.status,
              playerUid,
            }),
          );
          return;
        }

        tx.set(
          roomRef.collection('players').doc(playerUid),
          {
            score: FieldValue.increment(-wrongPenalty),
            wrongAnswers: FieldValue.increment(1),
          },
          { merge: true },
        );
        if (oneShot || !hasRemaining) {
          tx.update(
            roomRef,
            transitions.applyCommandTransition('judge_wrong_end', {
              roomStatus: room.status,
            }),
          );
        } else {
          tx.update(
            roomRef,
            transitions.applyCommandTransition('judge_wrong_reopen', {
              roomStatus: room.status,
              room,
              attempted,
              nowMs: Date.now(),
            }),
          );
        }
      });

      await autoAdvanceGameFlowIfNeeded(roomRef);
      await logEvent(roomId, uid, 'appeal_resolve', accepted ? 'Appeal accepted' : 'Appeal rejected');
      return { ok: true };
    },

    async apply_score({ uid, payload, roomId, roomRef }) {
      const targetUid = String(payload.targetUid || '');
      const delta = Number(payload.delta || 0);
      await requireHost(roomRef, uid);
      await roomRef.collection('players').doc(targetUid).set(
        { score: FieldValue.increment(delta) },
        { merge: true },
      );
      await logEvent(roomId, uid, 'score_manual', 'Ð ÑƒÑ‡Ð½Ð°Ñ ÐºÐ¾Ñ€Ñ€ÐµÐºÑ‚Ð¸Ñ€Ð¾Ð²ÐºÐ° ÑÑ‡ÐµÑ‚Ð°');
      return { ok: true };
    },

    async pause_game({ uid, roomId, roomRef }) {
      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        const room = roomSnap.data() || {};
        const role = await getPlayerRole(roomRef, uid, tx);
        if (uid !== room.hostUid) {
          const playerRef = roomRef.collection('players').doc(uid);
          const playerSnap = await tx.get(playerRef);
          const player = playerSnap.data() || {};
          if (!Boolean(player.connected) || !ensureVoiceRole(role)) {
            throw new functionsLib.https.HttpsError('permission-denied', 'Viewer cannot pause game');
          }
        }
        if (room.status === GAME_STATUS.PAUSED) {
          return;
        }
        tx.update(
          roomRef,
          transitions.applyCommandTransition('pause_game', {
            pausedByUid: uid,
            timerDeadlineAtMs: room.timerDeadlineAtMs,
            nowMs: Date.now(),
            phase: room.phase,
          }),
        );
      });
      await logEvent(roomId, uid, 'pause', 'Ð˜Ð³Ñ€Ð° Ð¿Ð¾ÑÑ‚Ð°Ð²Ð»ÐµÐ½Ð° Ð½Ð° Ð¿Ð°ÑƒÐ·Ñƒ');
      return { ok: true };
    },

    async resume_game({ uid, roomId, roomRef }) {
      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        const room = roomSnap.data() || {};
        if (room.status !== GAME_STATUS.PAUSED) {
          return;
        }
        if (uid !== room.pausedByUid && uid !== room.hostUid) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'Ð¡Ð½Ð¸Ð¼Ð°Ñ‚ÑŒ Ð¿Ð°ÑƒÐ·Ñƒ Ð¼Ð¾Ð¶ÐµÑ‚ Ñ‚Ð¾Ð»ÑŒÐºÐ¾ Ð¿Ð¾ÑÑ‚Ð°Ð²Ð¸Ð²ÑˆÐ¸Ð¹ Ð¸Ð»Ð¸ Ð²ÐµÐ´ÑƒÑ‰Ð¸Ð¹',
          );
        }
        tx.update(
          roomRef,
          transitions.applyCommandTransition('resume_game', { room }),
        );
      });
      await logEvent(roomId, uid, 'resume', 'ÐŸÐ°ÑƒÐ·Ð° ÑÐ½ÑÑ‚Ð°');
      return { ok: true };
    },

    async handle_timer_expiration({ uid, roomId, roomRef }) {
      await handleTimerExpirationByHost(roomRef, roomId, uid);
      return { ok: true };
    },
  };
}

module.exports = {
  createGameplayCommandHandlers,
};


