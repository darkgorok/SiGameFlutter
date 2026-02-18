function createGameFlowEngine(deps) {
  const {
    db,
    FieldValue,
    functionsLib,
    GAME_STATUS,
    GAME_PHASE,
    PLAYER_ROLE,
    FINAL_RESULT,
    GAME_TIMER_MS,
    withEngineStage,
    ensureVoiceRole,
    toFiniteNumber,
    getQuestionBehavior,
    logEvent,
    requireHost,
  } = deps;

  function isFinalPhase(phase) {
    return phase === GAME_PHASE.FINAL_SETUP ||
      phase === GAME_PHASE.FINAL_WAGERING ||
      phase === GAME_PHASE.FINAL_ANSWERING ||
      phase === GAME_PHASE.FINAL_REVEAL ||
      phase === GAME_PHASE.GAME_OVER;
  }

  function isConnectedVoicePlayer(player) {
    if (!player || typeof player !== 'object') {
      return false;
    }
    const role = player.role || PLAYER_ROLE.PLAYER;
    return Boolean(player.connected) && ensureVoiceRole(role, PLAYER_ROLE.SPECTATOR);
  }

  function getTimerMs(room, key) {
    const custom = Number(room?.rules?.timers?.[key]);
    if (Number.isFinite(custom) && custom >= 1000) {
      return Math.floor(custom);
    }
    return Number(GAME_TIMER_MS[key] || 1000);
  }

  async function getRoundStats(roomRef) {
    const questionsSnap = await roomRef.collection('questions').get();
    let maxRound = 1;
    const unusedRounds = new Set();

    questionsSnap.docs.forEach((doc) => {
      const data = doc.data() || {};
      const round = Math.max(1, Number(data.round || 1));
      maxRound = Math.max(maxRound, round);
      if (data.used !== true) {
        unusedRounds.add(round);
      }
    });

    return {
      maxRound,
      unusedRounds: [...unusedRounds].sort((a, b) => a - b),
    };
  }

  function getNextPlayableRound(unusedRounds, currentRound) {
    return unusedRounds.find((round) => round > currentRound) || null;
  }

  async function buildFinalRoundPayload(roomRef, currentRound = 1) {
    const [playersSnap, roundStats, questionsSnap] = await Promise.all([
      roomRef.collection('players').get(),
      getRoundStats(roomRef),
      roomRef.collection('questions').get(),
    ]);

    let eligible = playersSnap.docs
      .filter((playerDoc) => {
        const score = Number(playerDoc.data().score || 0);
        return score > 0 && isConnectedVoicePlayer(playerDoc.data());
      })
      .map((playerDoc) => playerDoc.id);

    if (eligible.length === 0) {
      eligible = playersSnap.docs
        .filter((playerDoc) => isConnectedVoicePlayer(playerDoc.data()))
        .map((playerDoc) => playerDoc.id);
    }

    const finalRoundNumber = Math.max(
      roundStats.maxRound + 1,
      Math.max(1, Number(currentRound || 1)) + 1,
    );

    const allQuestions = questionsSnap.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }));

    const remainingQuestions = allQuestions.filter((q) => q.used !== true);

    let finalThemePool = [...new Set(
      remainingQuestions
        .map((q) => String(q.theme || '').trim())
        .filter((theme) => theme.length > 0),
    )].sort((a, b) => a.localeCompare(b));

    if (finalThemePool.length === 0) {
      finalThemePool = [...new Set(
        allQuestions
          .map((q) => String(q.theme || '').trim())
          .filter((theme) => theme.length > 0),
      )].sort((a, b) => a.localeCompare(b));
    }

    let selectedFinal = null;
    if (finalThemePool.length === 1) {
      const selectedTheme = finalThemePool[0];
      let selectedQuestion = remainingQuestions
        .filter((q) => String(q.theme || '').trim() === selectedTheme)
        .sort((a, b) => {
          const byRound = Number(b.round || 1) - Number(a.round || 1);
          if (byRound !== 0) {
            return byRound;
          }
          return Number(a.cost || 0) - Number(b.cost || 0);
        })[0];

      if (!selectedQuestion) {
        selectedQuestion = allQuestions
          .filter((q) => String(q.theme || '').trim() === selectedTheme)
          .sort((a, b) => {
            const byRound = Number(b.round || 1) - Number(a.round || 1);
            if (byRound !== 0) {
              return byRound;
            }
            return Number(a.cost || 0) - Number(b.cost || 0);
          })[0];
      }

      if (selectedQuestion) {
        selectedFinal = {
          theme: selectedTheme,
          question: String(selectedQuestion.text || ''),
          answer: String(selectedQuestion.answer || ''),
        };
      }
    }

    const eligibleWithScores = playersSnap.docs
      .filter((playerDoc) => eligible.includes(playerDoc.id))
      .map((playerDoc) => ({
        uid: playerDoc.id,
        score: Number(playerDoc.data().score || 0),
      }))
      .sort((a, b) => (a.score - b.score) || a.uid.localeCompare(b.uid));
    const finalThemeDeleteOrder = eligibleWithScores.map((item) => item.uid);
    const minScore = eligibleWithScores.length > 0 ? eligibleWithScores[0].score : null;
    const finalThemeDeleteCandidates = minScore === null
      ? []
      : eligibleWithScores
        .filter((item) => item.score === minScore)
        .map((item) => item.uid);
    const finalThemeDeleteNeedsSelection = finalThemeDeleteCandidates.length > 1;
    const finalThemeDeleteIndex = finalThemeDeleteOrder.length === 0
      ? 0
      : (finalThemeDeleteNeedsSelection
        ? -1
        : finalThemeDeleteOrder.indexOf(finalThemeDeleteCandidates[0]));
    const finalThemeDeleteCurrentUid = finalThemePool.length > 1 &&
      finalThemeDeleteOrder.length > 0 &&
      !finalThemeDeleteNeedsSelection
      ? finalThemeDeleteCandidates[0]
      : null;

    return {
      eligible,
      finalRoundNumber,
      finalThemePool,
      selectedFinal,
      finalThemeDeleteOrder,
      finalThemeDeleteCandidates,
      finalThemeDeleteNeedsSelection,
      finalThemeDeleteIndex,
      finalThemeDeleteCurrentUid,
    };
  }

  async function revealFinalByHost(roomRef, roomId, hostUid) {
    await requireHost(roomRef, hostUid);
    const roomSnap = await roomRef.get();
    const room = roomSnap.data() || {};
    const eligible = Array.isArray(room.finalEligibleUids)
      ? room.finalEligibleUids
        .map((v) => String(v || '').trim())
        .filter((v) => v.length > 0)
      : [];

    if (room.phase === GAME_PHASE.FINAL_ANSWERING) {
      const players = await roomRef.collection('players').get();
      const hasPending = players.docs.some((playerDoc) => {
        if (!eligible.includes(playerDoc.id)) {
          return false;
        }
        return String(playerDoc.data()?.finalResult || FINAL_RESULT.PENDING) === FINAL_RESULT.PENDING;
      });
      if (hasPending) {
        throw new functionsLib.https.HttpsError(
          'failed-precondition',
          'All final players must be marked before reveal',
        );
      }

      const answerOrder = Array.isArray(room.finalAnswerOrder)
        ? room.finalAnswerOrder
          .map((v) => String(v || '').trim())
          .filter((v) => v.length > 0)
        : [];
      const revealOrder = answerOrder.length > 0
        ? answerOrder
        : [...eligible].sort((a, b) => a.localeCompare(b));
      const firstUid = revealOrder.length > 0 ? revealOrder[0] : null;

      const batch = db.batch();
      players.docs.forEach((playerDoc) => {
        if (eligible.includes(playerDoc.id)) {
          batch.set(playerDoc.ref, { finalRevealed: false }, { merge: true });
        }
      });
      batch.update(
        roomRef,
        withEngineStage(
          {
            phase: GAME_PHASE.FINAL_REVEAL,
            status: GAME_STATUS.FINAL_ROUND,
            finalRevealOrder: revealOrder,
            finalRevealIndex: 0,
            finalRevealCurrentUid: firstUid,
            timerDeadlineAtMs: firstUid ? Date.now() + getTimerMs(room, 'FINAL_REVEAL_STEP') : null,
            timerRemainingMs: null,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { phase: GAME_PHASE.FINAL_REVEAL, status: GAME_STATUS.FINAL_ROUND },
        ),
      );
      await batch.commit();
      await logEvent(roomId, hostUid, 'final_reveal_start', 'Final reveal started');
      return;
    }

    if (room.phase !== GAME_PHASE.FINAL_REVEAL) {
      throw new functionsLib.https.HttpsError(
        'failed-precondition',
        'Final reveal is not active',
      );
    }

    let stepUid = null;
    let endedWithoutCurrentUid = false;

    await db.runTransaction(async (tx) => {
      const freshRoomSnap = await tx.get(roomRef);
      if (!freshRoomSnap.exists) {
        throw new functionsLib.https.HttpsError('not-found', 'Room not found');
      }
      const freshRoom = freshRoomSnap.data() || {};
      if (freshRoom.phase !== GAME_PHASE.FINAL_REVEAL) {
        throw new functionsLib.https.HttpsError(
          'failed-precondition',
          'Final reveal is not active',
        );
      }

      const freshEligible = Array.isArray(freshRoom.finalEligibleUids)
        ? freshRoom.finalEligibleUids
          .map((v) => String(v || '').trim())
          .filter((v) => v.length > 0)
        : [];
      const revealOrder = Array.isArray(freshRoom.finalRevealOrder)
        ? freshRoom.finalRevealOrder
          .map((v) => String(v || '').trim())
          .filter((v) => v.length > 0)
        : [];
      const fallbackOrder = revealOrder.length > 0
        ? revealOrder
        : [...freshEligible].sort((a, b) => a.localeCompare(b));
      const currentIndex = Math.max(0, Number(freshRoom.finalRevealIndex || 0));
      const currentUid = String(freshRoom.finalRevealCurrentUid || '').trim() ||
        fallbackOrder[currentIndex] ||
        '';

      if (!currentUid) {
        tx.update(
          roomRef,
          withEngineStage(
            {
              phase: GAME_PHASE.GAME_OVER,
              status: GAME_STATUS.COMPLETED,
              finalRevealCurrentUid: null,
              timerDeadlineAtMs: null,
              timerRemainingMs: null,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { phase: GAME_PHASE.GAME_OVER, status: GAME_STATUS.COMPLETED },
          ),
        );
        endedWithoutCurrentUid = true;
        return;
      }

      stepUid = currentUid;
      const playerRef = roomRef.collection('players').doc(currentUid);
      const playerSnap = await tx.get(playerRef);
      const player = playerSnap.data() || {};
      const alreadyRevealed = Boolean(player.finalRevealed);
      if (!alreadyRevealed) {
        const wager = Number(player.finalWager || 0);
        const result = String(player.finalResult || FINAL_RESULT.PENDING);
        const correct = result === FINAL_RESULT.CORRECT;
        const wrong = result === FINAL_RESULT.WRONG;
        const delta = correct ? wager : wrong ? -wager : 0;
        tx.set(
          playerRef,
          {
            score: FieldValue.increment(delta),
            correctAnswers: FieldValue.increment(correct ? 1 : 0),
            wrongAnswers: FieldValue.increment(wrong ? 1 : 0),
            finalRevealed: true,
          },
          { merge: true },
        );
      }

      const nextIndex = currentIndex + 1;
      const nextUid = fallbackOrder[nextIndex] || null;
      if (nextUid) {
        tx.update(
          roomRef,
          withEngineStage(
            {
              phase: GAME_PHASE.FINAL_REVEAL,
              status: GAME_STATUS.FINAL_ROUND,
              finalRevealOrder: fallbackOrder,
              finalRevealIndex: nextIndex,
              finalRevealCurrentUid: nextUid,
              timerDeadlineAtMs: Date.now() + getTimerMs(freshRoom, 'FINAL_REVEAL_STEP'),
              timerRemainingMs: null,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { phase: GAME_PHASE.FINAL_REVEAL, status: GAME_STATUS.FINAL_ROUND },
          ),
        );
      } else {
        tx.update(
          roomRef,
          withEngineStage(
            {
              phase: GAME_PHASE.GAME_OVER,
              status: GAME_STATUS.COMPLETED,
              finalRevealOrder: fallbackOrder,
              finalRevealIndex: fallbackOrder.length,
              finalRevealCurrentUid: null,
              finalAnswerCurrentUid: null,
              timerDeadlineAtMs: null,
              timerRemainingMs: null,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { phase: GAME_PHASE.GAME_OVER, status: GAME_STATUS.COMPLETED },
          ),
        );
      }
    });

    if (endedWithoutCurrentUid) {
      await logEvent(roomId, hostUid, 'final_reveal_end', 'Final reveal completed');
      return;
    }
    await logEvent(roomId, hostUid, 'final_reveal_step', `Final reveal for ${stepUid}`);
  }

  async function autoAdvanceGameFlowIfNeeded(roomRef) {
    while (true) {
      const roomSnap = await roomRef.get();
      if (!roomSnap.exists) {
        return;
      }
      const room = roomSnap.data() || {};
      const phase = String(room.phase || '');
      const status = String(room.status || '');
      const currentRound = Number(room.currentRound || 1);

      if (phase !== GAME_PHASE.BOARD_SELECT || status !== GAME_STATUS.IN_GAME) {
        return;
      }
      if (currentRound <= 0) {
        return;
      }

      const playersSnap = await roomRef.collection('players').get();
      const playersByUid = new Map(
        playersSnap.docs.map((doc) => [doc.id, doc.data() || {}]),
      );
      const connectedVoiceUids = playersSnap.docs
        .filter((doc) => isConnectedVoicePlayer(doc.data()))
        .map((doc) => doc.id)
        .sort((a, b) => a.localeCompare(b));
      const chooserUid = String(room.chooserUid || '').trim();
      const chooserPlayer = playersByUid.get(chooserUid) || null;
      const chooserIsConnectedVoice = isConnectedVoicePlayer(chooserPlayer);
      if (!chooserIsConnectedVoice) {
        const hostUid = String(room.hostUid || '').trim();
        const fallbackChooser = connectedVoiceUids[0] || hostUid || chooserUid;
        if (fallbackChooser && fallbackChooser !== chooserUid) {
          await roomRef.update(
            withEngineStage(
              {
                chooserUid: fallbackChooser,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.BOARD_SELECT, status: GAME_STATUS.IN_GAME },
            ),
          );
          continue;
        }
      }

      const stats = await getRoundStats(roomRef);
      if (stats.unusedRounds.includes(currentRound)) {
        return;
      }

      const nextRound = getNextPlayableRound(stats.unusedRounds, currentRound);

      if (nextRound !== null) {
        await roomRef.update(
          withEngineStage(
            {
              currentRound: nextRound,
              phase: GAME_PHASE.BOARD_SELECT,
              status: GAME_STATUS.IN_GAME,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { phase: GAME_PHASE.BOARD_SELECT, status: GAME_STATUS.IN_GAME },
          ),
        );
        continue;
      }

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
        currentRound,
      );

      await roomRef.update(
        withEngineStage(
          {
            status: GAME_STATUS.FINAL_ROUND,
            currentRound: finalRoundNumber,
            phase: GAME_PHASE.FINAL_SETUP,
            currentQuestionId: null,
            activeQuestion: null,
            numericAnswers: null,
            finalEligibleUids: eligible,
            finalThemePool,
            finalThemeDeleteOrder,
            finalThemeDeleteCandidates,
            finalThemeDeleteNeedsSelection,
            finalThemeDeleteIndex,
            finalThemeDeleteCurrentUid,
            finalAnswerOrder: [],
            finalAnswerIndex: 0,
            finalAnswerCurrentUid: null,
            finalTheme: selectedFinal?.theme || null,
            finalQuestion: selectedFinal?.question || null,
            finalAnswer: selectedFinal?.answer || null,
            timerDeadlineAtMs: null,
            timerRemainingMs: null,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { phase: GAME_PHASE.FINAL_SETUP, status: GAME_STATUS.FINAL_ROUND },
        ),
      );
      return;
    }
  }

  async function autoHealAfterRosterChange(roomRef, roomId) {
    let shouldTriggerTimer = false;
    let hostUidForTimer = '';

    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        return;
      }
      const room = roomSnap.data() || {};
      const phase = String(room.phase || '');
      const status = String(room.status || '');
      hostUidForTimer = String(room.hostUid || '').trim();

      const playersSnap = await tx.get(roomRef.collection('players'));
      const playersByUid = new Map(
        playersSnap.docs.map((doc) => [doc.id, doc.data() || {}]),
      );
      const connectedVoiceUids = playersSnap.docs
        .filter((doc) => isConnectedVoicePlayer(doc.data()))
        .map((doc) => doc.id)
        .sort((a, b) => a.localeCompare(b));

      const update = {};
      const nowMs = Date.now();

      if (phase === GAME_PHASE.BOARD_SELECT && status === GAME_STATUS.IN_GAME) {
        const chooserUid = String(room.chooserUid || '').trim();
        const chooserPlayer = playersByUid.get(chooserUid) || null;
        if (!isConnectedVoicePlayer(chooserPlayer)) {
          const fallbackChooser = connectedVoiceUids[0] || hostUidForTimer || chooserUid;
          if (fallbackChooser && fallbackChooser !== chooserUid) {
            update.chooserUid = fallbackChooser;
          }
        }
      }

      if (phase === GAME_PHASE.QUESTION_REVEAL) {
        if (connectedVoiceUids.length === 0) {
          update.timerDeadlineAtMs = nowMs - 1;
          update.timerRemainingMs = null;
          shouldTriggerTimer = true;
        }
      }

      if (phase === GAME_PHASE.CAT_TARGETING || phase === GAME_PHASE.WAGER_BIDDING) {
        const chooserUid = String(room.chooserUid || '').trim();
        const chooserPlayer = playersByUid.get(chooserUid) || null;
        if (!isConnectedVoicePlayer(chooserPlayer) || connectedVoiceUids.length === 0) {
          update.timerDeadlineAtMs = nowMs - 1;
          update.timerRemainingMs = null;
          shouldTriggerTimer = true;
        }
      }

      if (phase === GAME_PHASE.ANSWERING || phase === GAME_PHASE.ANSWER_REVIEW) {
        const currentAttemptUid = String(room.currentAttemptUid || '').trim();
        if (currentAttemptUid) {
          const currentAttemptPlayer = playersByUid.get(currentAttemptUid) || null;
          if (!isConnectedVoicePlayer(currentAttemptPlayer)) {
            update.timerDeadlineAtMs = nowMs - 1;
            update.timerRemainingMs = null;
            shouldTriggerTimer = true;
          }
        } else if (phase === GAME_PHASE.ANSWERING && connectedVoiceUids.length === 0) {
          update.timerDeadlineAtMs = nowMs - 1;
          update.timerRemainingMs = null;
          shouldTriggerTimer = true;
        }
      }

      if (phase === GAME_PHASE.FINAL_WAGERING) {
        const eligible = Array.isArray(room.finalEligibleUids)
          ? room.finalEligibleUids
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        let autoSubmitted = false;
        for (const playerUid of eligible) {
          const player = playersByUid.get(playerUid) || {};
          if (!isConnectedVoicePlayer(player) && !Boolean(player.finalWagerSubmitted)) {
            tx.set(
              roomRef.collection('players').doc(playerUid),
              { finalWager: 0, finalWagerSubmitted: true },
              { merge: true },
            );
            autoSubmitted = true;
          }
        }
        if (autoSubmitted) {
          update.timerDeadlineAtMs = nowMs - 1;
          update.timerRemainingMs = null;
          shouldTriggerTimer = true;
        }
      }

      if (phase === GAME_PHASE.FINAL_ANSWERING) {
        const eligible = Array.isArray(room.finalEligibleUids)
          ? room.finalEligibleUids
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        const orderRaw = Array.isArray(room.finalAnswerOrder)
          ? room.finalAnswerOrder
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        const order = orderRaw.length > 0
          ? orderRaw
          : [...eligible].sort((a, b) => a.localeCompare(b));

        const resultByUid = new Map();
        for (const playerUid of eligible) {
          const player = playersByUid.get(playerUid) || {};
          resultByUid.set(playerUid, String(player.finalResult || FINAL_RESULT.PENDING));
        }

        let changedAnyResult = false;
        for (const playerUid of eligible) {
          const player = playersByUid.get(playerUid) || {};
          const result = String(resultByUid.get(playerUid) || FINAL_RESULT.PENDING);
          if (!isConnectedVoicePlayer(player) && result === FINAL_RESULT.PENDING) {
            tx.set(
              roomRef.collection('players').doc(playerUid),
              { finalResult: FINAL_RESULT.NO_ANSWER },
              { merge: true },
            );
            resultByUid.set(playerUid, FINAL_RESULT.NO_ANSWER);
            changedAnyResult = true;
          }
        }

        if (changedAnyResult) {
          let nextIndex = order.length;
          let nextUid = null;
          for (let i = 0; i < order.length; i += 1) {
            const candidateUid = order[i];
            const candidateResult = String(resultByUid.get(candidateUid) || FINAL_RESULT.PENDING);
            if (candidateResult === FINAL_RESULT.PENDING) {
              nextIndex = i;
              nextUid = candidateUid;
              break;
            }
          }
          update.finalAnswerOrder = order;
          update.finalAnswerIndex = nextIndex;
          update.finalAnswerCurrentUid = nextUid;
          if (!nextUid) {
            update.timerDeadlineAtMs = nowMs - 1;
            update.timerRemainingMs = null;
            shouldTriggerTimer = true;
          }
        }
      }

      if (phase === GAME_PHASE.FINAL_REVEAL && status === GAME_STATUS.FINAL_ROUND) {
        const eligibleRaw = Array.isArray(room.finalEligibleUids)
          ? room.finalEligibleUids
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        const eligible = eligibleRaw.filter((uid) => playersByUid.has(uid));

        const revealOrderRaw = Array.isArray(room.finalRevealOrder)
          ? room.finalRevealOrder
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        const revealOrderBase = revealOrderRaw.length > 0
          ? revealOrderRaw
          : [...eligible].sort((a, b) => a.localeCompare(b));
        const revealOrder = revealOrderBase
          .filter((uid) => eligible.includes(uid));
        for (const uid of eligible.sort((a, b) => a.localeCompare(b))) {
          if (!revealOrder.includes(uid)) {
            revealOrder.push(uid);
          }
        }

        if (revealOrder.length === 0) {
          tx.update(
            roomRef,
            withEngineStage(
              {
                status: GAME_STATUS.COMPLETED,
                phase: GAME_PHASE.GAME_OVER,
                finalRevealOrder: [],
                finalRevealIndex: 0,
                finalRevealCurrentUid: null,
                timerDeadlineAtMs: null,
                timerRemainingMs: null,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.GAME_OVER, status: GAME_STATUS.COMPLETED },
            ),
          );
          return;
        }

        const currentUidRaw = String(room.finalRevealCurrentUid || '').trim();
        const currentIndexRaw = Math.max(0, Number(room.finalRevealIndex || 0));
        const currentUid = revealOrder.includes(currentUidRaw) ? currentUidRaw : null;

        let nextIndex = currentUid
          ? revealOrder.indexOf(currentUid)
          : Math.min(currentIndexRaw, revealOrder.length - 1);
        let nextUid = revealOrder[nextIndex] || null;
        if (!nextUid) {
          nextIndex = 0;
          nextUid = revealOrder[0];
        }

        for (let i = 0; i < revealOrder.length; i += 1) {
          const probeUid = revealOrder[(nextIndex + i) % revealOrder.length];
          const probePlayer = playersByUid.get(probeUid) || {};
          if (!Boolean(probePlayer.finalRevealed)) {
            nextIndex = revealOrder.indexOf(probeUid);
            nextUid = probeUid;
            break;
          }
        }

        const allRevealed = revealOrder.every((uid) => {
          const player = playersByUid.get(uid) || {};
          return Boolean(player.finalRevealed);
        });
        if (allRevealed) {
          tx.update(
            roomRef,
            withEngineStage(
              {
                status: GAME_STATUS.COMPLETED,
                phase: GAME_PHASE.GAME_OVER,
                finalRevealOrder: revealOrder,
                finalRevealIndex: revealOrder.length,
                finalRevealCurrentUid: null,
                timerDeadlineAtMs: null,
                timerRemainingMs: null,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.GAME_OVER, status: GAME_STATUS.COMPLETED },
            ),
          );
          return;
        }

        if (JSON.stringify(eligibleRaw) !== JSON.stringify(eligible)) {
          update.finalEligibleUids = eligible;
        }
        if (JSON.stringify(revealOrderRaw) !== JSON.stringify(revealOrder)) {
          update.finalRevealOrder = revealOrder;
        }
        if (Number(room.finalRevealIndex || 0) !== Number(nextIndex)) {
          update.finalRevealIndex = nextIndex;
        }
        if (String(room.finalRevealCurrentUid || '') !== String(nextUid || '')) {
          update.finalRevealCurrentUid = nextUid;
        }
        if (!room.timerDeadlineAtMs) {
          update.timerDeadlineAtMs = nowMs + getTimerMs(room, 'FINAL_REVEAL_STEP');
          update.timerRemainingMs = null;
        }
      }

      if (phase === GAME_PHASE.FINAL_SETUP) {
        const finalThemePool = Array.isArray(room.finalThemePool)
          ? room.finalThemePool
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        const originalEligible = Array.isArray(room.finalEligibleUids)
          ? room.finalEligibleUids
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        const eligible = originalEligible.filter((uid) => {
          const player = playersByUid.get(uid) || null;
          return isConnectedVoicePlayer(player);
        });

        const originalOrder = Array.isArray(room.finalThemeDeleteOrder)
          ? room.finalThemeDeleteOrder
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        const order = originalOrder
          .filter((uid) => eligible.includes(uid));
        const currentUidRaw = String(room.finalThemeDeleteCurrentUid || '').trim();
        const currentUid = order.includes(currentUidRaw) ? currentUidRaw : null;
        const nextIndex = currentUid
          ? order.indexOf(currentUid)
          : (order.length > 0
            ? Math.max(0, Math.min(Number(room.finalThemeDeleteIndex || 0), order.length - 1))
            : 0);

        let candidates = [];
        let needsSelection = false;
        let effectiveCurrentUid = currentUid;
        let effectiveIndex = nextIndex;

        if (finalThemePool.length > 1 && order.length > 0) {
          const orderedWithScores = order
            .map((uid) => ({ uid, score: Number(playersByUid.get(uid)?.score || 0) }));
          const minScore = orderedWithScores
            .reduce((acc, item) => Math.min(acc, item.score), Number.POSITIVE_INFINITY);
          candidates = orderedWithScores
            .filter((item) => item.score === minScore)
            .map((item) => item.uid);

          if (candidates.length > 1) {
            if (effectiveCurrentUid && candidates.includes(effectiveCurrentUid)) {
              needsSelection = false;
              effectiveIndex = order.indexOf(effectiveCurrentUid);
            } else {
              needsSelection = true;
              effectiveCurrentUid = null;
              effectiveIndex = -1;
            }
          } else {
            needsSelection = false;
            const defaultUid = candidates[0] || order[Math.max(0, effectiveIndex)] || order[0];
            if (!effectiveCurrentUid) {
              effectiveCurrentUid = defaultUid || null;
            }
            if (effectiveCurrentUid && !order.includes(effectiveCurrentUid)) {
              effectiveCurrentUid = defaultUid || null;
            }
            effectiveIndex = effectiveCurrentUid ? order.indexOf(effectiveCurrentUid) : 0;
          }
        } else {
          candidates = [];
          needsSelection = false;
          effectiveCurrentUid = null;
          effectiveIndex = 0;
        }

        if (JSON.stringify(originalEligible) !== JSON.stringify(eligible)) {
          update.finalEligibleUids = eligible;
        }
        if (JSON.stringify(originalOrder) !== JSON.stringify(order)) {
          update.finalThemeDeleteOrder = order;
        }
        const originalCandidates = Array.isArray(room.finalThemeDeleteCandidates)
          ? room.finalThemeDeleteCandidates
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        if (JSON.stringify(originalCandidates) !== JSON.stringify(candidates)) {
          update.finalThemeDeleteCandidates = candidates;
        }
        if (Boolean(room.finalThemeDeleteNeedsSelection) !== needsSelection) {
          update.finalThemeDeleteNeedsSelection = needsSelection;
        }
        if (String(room.finalThemeDeleteCurrentUid || '') !== String(effectiveCurrentUid || '')) {
          update.finalThemeDeleteCurrentUid = effectiveCurrentUid;
        }
        if (Number(room.finalThemeDeleteIndex || 0) !== Number(effectiveIndex || 0)) {
          update.finalThemeDeleteIndex = effectiveIndex;
        }
      }

      if (Object.keys(update).length > 0) {
        tx.update(
          roomRef,
          withEngineStage(
            {
              ...update,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { phase: room.phase, status: room.status },
          ),
        );
      }
    });

    if (shouldTriggerTimer && roomId && hostUidForTimer) {
      await handleTimerExpirationByHost(roomRef, roomId, hostUidForTimer);
    }
    await autoAdvanceGameFlowIfNeeded(roomRef);
  }

  async function handleTimerExpirationByHost(roomRef, roomId, hostUid) {
    let shouldRevealFinal = false;

    await db.runTransaction(async (tx) => {
      const roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        throw new functionsLib.https.HttpsError('not-found', 'Room not found');
      }
      const room = roomSnap.data();

      if (room.hostUid !== hostUid) {
        throw new functionsLib.https.HttpsError(
          'permission-denied',
          'Only host can handle timer expiration',
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
        if (!room.activeQuestion) {
          tx.update(
            roomRef,
            withEngineStage(
              {
                phase: GAME_PHASE.BOARD_SELECT,
                currentQuestionId: null,
                activeQuestion: null,
                buzzQueue: [],
                currentAttemptUid: null,
                pendingAnswer: null,
                targetedUid: null,
                wagerValue: null,
                numericAnswers: null,
                timerDeadlineAtMs: null,
                timerRemainingMs: null,
                pressBlockedUntilMs: null,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.BOARD_SELECT, status: room.status },
            ),
          );
          return;
        }
        tx.update(
          roomRef,
          withEngineStage(
            {
              phase: GAME_PHASE.ANSWERING,
              currentAttemptUid: null,
              pendingAnswer: null,
              timerDeadlineAtMs: Date.now() + getTimerMs(room, 'PRESSING'),
              timerRemainingMs: null,
              pressBlockedUntilMs: null,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { phase: GAME_PHASE.ANSWERING, status: room.status },
          ),
        );
        return;
      }

      if (room.phase === GAME_PHASE.CAT_TARGETING) {
        const playersSnap = await tx.get(roomRef.collection('players'));
        const voicePlayers = playersSnap.docs
          .filter((doc) => isConnectedVoicePlayer(doc.data()))
          .map((doc) => doc.id)
          .sort((a, b) => a.localeCompare(b));
        if (voicePlayers.length === 0) {
          tx.update(
            roomRef,
            withEngineStage(
              {
                phase: GAME_PHASE.BOARD_SELECT,
                currentQuestionId: null,
                activeQuestion: null,
                buzzQueue: [],
                currentAttemptUid: null,
                pendingAnswer: null,
                targetedUid: null,
                wagerValue: null,
                numericAnswers: null,
                timerDeadlineAtMs: null,
                timerRemainingMs: null,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.BOARD_SELECT, status: room.status },
            ),
          );
          return;
        }

        const chooserUid = String(room.chooserUid || '').trim();
        const targetUid = voicePlayers.includes(chooserUid) ? chooserUid : voicePlayers[0];
        tx.set(
          roomRef.collection('players').doc(targetUid),
          { buzzCount: FieldValue.increment(1) },
          { merge: true },
        );
        tx.update(
          roomRef,
          withEngineStage(
            {
              phase: GAME_PHASE.ANSWERING,
              targetedUid: targetUid,
              currentAttemptUid: targetUid,
              buzzQueue: [targetUid],
              timerDeadlineAtMs: Date.now() + getTimerMs(room, 'ANSWERING'),
              timerRemainingMs: null,
              pressBlockedUntilMs: null,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { phase: GAME_PHASE.ANSWERING, status: room.status },
          ),
        );
        return;
      }

      if (room.phase === GAME_PHASE.WAGER_BIDDING) {
        const playersSnap = await tx.get(roomRef.collection('players'));
        const playersByUid = new Map(playersSnap.docs.map((doc) => [doc.id, doc.data() || {}]));
        const voicePlayers = playersSnap.docs
          .filter((doc) => isConnectedVoicePlayer(doc.data()))
          .map((doc) => doc.id)
          .sort((a, b) => a.localeCompare(b));

        const chooserUid = String(room.chooserUid || '').trim();
        const behavior = getQuestionBehavior(
          room.activeQuestion?.kind || room.activeQuestion?.type,
        );
        let actorUid = voicePlayers.includes(chooserUid) ? chooserUid : voicePlayers[0];
        if (behavior.kind === 'stake') {
          actorUid = [...voicePlayers]
            .sort((a, b) => {
              const scoreA = Number(playersByUid.get(a)?.score || 0);
              const scoreB = Number(playersByUid.get(b)?.score || 0);
              if (scoreA !== scoreB) {
                return scoreB - scoreA;
              }
              return a.localeCompare(b);
            })[0] || actorUid;
        }
        if (!actorUid) {
          tx.update(
            roomRef,
            withEngineStage(
              {
                phase: GAME_PHASE.BOARD_SELECT,
                currentQuestionId: null,
                activeQuestion: null,
                buzzQueue: [],
                currentAttemptUid: null,
                pendingAnswer: null,
                targetedUid: null,
                wagerValue: null,
                numericAnswers: null,
                timerDeadlineAtMs: null,
                timerRemainingMs: null,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.BOARD_SELECT, status: room.status },
            ),
          );
          return;
        }

        const score = Number(playersByUid.get(actorUid)?.score || 0);
        const maxWager = score > 0 ? score : Number(room.activeQuestion?.cost || 100);
        const minWager = maxWager >= 100 ? 100 : 0;
        const safeWager = Math.max(minWager, maxWager);
        tx.set(
          roomRef.collection('players').doc(actorUid),
          { buzzCount: FieldValue.increment(1) },
          { merge: true },
        );
        tx.update(
          roomRef,
          withEngineStage(
            {
              phase: GAME_PHASE.ANSWERING,
              wagerValue: safeWager,
              currentAttemptUid: actorUid,
              buzzQueue: [actorUid],
              timerDeadlineAtMs: Date.now() + getTimerMs(room, 'ANSWERING'),
              timerRemainingMs: null,
              pressBlockedUntilMs: null,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { phase: GAME_PHASE.ANSWERING, status: room.status },
          ),
        );
        return;
      }

      if (room.phase === GAME_PHASE.ANSWERING) {
        const current = room.currentAttemptUid;
        const nowMs = Date.now();
        const pressBlockedUntilMs = Number(room.pressBlockedUntilMs || 0);
        if (!current) {
          const activeBehavior = getQuestionBehavior(
            room.activeQuestion?.kind || room.activeQuestion?.type,
          );
          if (room.forAllMode === true || activeBehavior.isForAll) {
            const submitted = Array.isArray(room.forAllSubmittedUids)
              ? room.forAllSubmittedUids
                .map((v) => String(v || '').trim())
                .filter((v) => v.length > 0)
              : [];
            if (submitted.length > 0) {
              const reviewOrder = [...submitted].sort((a, b) => a.localeCompare(b));
              tx.update(
                roomRef,
                withEngineStage(
                  {
                    phase: GAME_PHASE.ANSWER_REVIEW,
                    forAllMode: true,
                    forAllReviewOrder: reviewOrder,
                    forAllReviewIndex: 0,
                    currentAttemptUid: reviewOrder[0] || null,
                    pendingAnswer: '[voice]',
                    appealActive: false,
                    appealRequestedByUid: null,
                    appealForUid: null,
                    timerDeadlineAtMs: nowMs + getTimerMs(room, 'ANSWER_REVIEW'),
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
                withEngineStage(
                  {
                    phase: GAME_PHASE.BOARD_SELECT,
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
                    forAllMode: false,
                    forAllSubmittedUids: [],
                    forAllReviewOrder: [],
                    forAllReviewIndex: 0,
                    timerDeadlineAtMs: null,
                    timerRemainingMs: null,
                    pressBlockedUntilMs: null,
                    updatedAt: FieldValue.serverTimestamp(),
                  },
                  { phase: GAME_PHASE.BOARD_SELECT, status: room.status },
                ),
              );
            }
            return;
          }
          if (pressBlockedUntilMs > nowMs) {
            return;
          }
          if (pressBlockedUntilMs > 0) {
            tx.update(
              roomRef,
              withEngineStage(
                {
                  phase: GAME_PHASE.ANSWERING,
                  currentAttemptUid: null,
                  pendingAnswer: null,
                  timerDeadlineAtMs: nowMs + getTimerMs(room, 'PRESSING'),
                  timerRemainingMs: null,
                  pressBlockedUntilMs: null,
                  updatedAt: FieldValue.serverTimestamp(),
                },
                { phase: GAME_PHASE.ANSWERING, status: room.status },
              ),
            );
            return;
          }
          tx.update(
            roomRef,
            withEngineStage(
              {
                phase: GAME_PHASE.BOARD_SELECT,
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
                pressBlockedUntilMs: null,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.BOARD_SELECT, status: room.status },
            ),
          );
          return;
        }

        if (room.activeQuestion?.type === 'closest_number') {
          const amount = Number(room.wagerValue || room.activeQuestion?.cost || 0);
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
          const rawAnswers = room.numericAnswers && typeof room.numericAnswers === 'object'
            ? room.numericAnswers
            : {};
          const answers = Object.entries(rawAnswers)
            .map(([playerUid, value]) => ({ playerUid, value: toFiniteNumber(value) }))
            .filter((entry) => entry.value !== null);

          if (target !== null && answers.length > 0) {
            let minDiff = Number.POSITIVE_INFINITY;
            for (const entry of answers) {
              const diff = Math.abs(entry.value - target);
              if (diff < minDiff) {
                minDiff = diff;
              }
            }

            const winners = answers
              .filter((entry) => Math.abs(entry.value - target) === minDiff)
              .map((entry) => entry.playerUid)
              .sort((a, b) => a.localeCompare(b));

            for (const winnerUid of winners) {
              const value = toFiniteNumber(rawAnswers[winnerUid]);
              const isExact = value !== null && value === target;
              const scoreDelta = isExact ? amount * 2 : amount;
              tx.set(
                roomRef.collection('players').doc(winnerUid),
                {
                  score: FieldValue.increment(scoreDelta),
                  correctAnswers: FieldValue.increment(1),
                },
                { merge: true },
              );
            }

            tx.update(roomRef, { chooserUid: winners[0] });
          }

          tx.update(
            roomRef,
            withEngineStage(
              {
                phase: GAME_PHASE.BOARD_SELECT,
                currentQuestionId: null,
                activeQuestion: null,
                buzzQueue: [],
                currentAttemptUid: null,
                pendingAnswer: null,
                targetedUid: null,
                wagerValue: null,
                numericAnswers: null,
                timerDeadlineAtMs: null,
                timerRemainingMs: null,
                pressBlockedUntilMs: null,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.BOARD_SELECT, status: room.status },
            ),
          );
          return;
        }

        const attempted = Array.isArray(room.buzzQueue) ? [...room.buzzQueue] : [];
        if (current && !attempted.includes(current)) {
          attempted.push(current);
        }
        const behavior = getQuestionBehavior(
          room.activeQuestion?.kind || room.activeQuestion?.type,
        );
        const oneShot = behavior.oneShot;
        const playersSnap = await tx.get(roomRef.collection('players'));
        const hasRemaining = playersSnap.docs.some((doc) => {
          return isConnectedVoicePlayer(doc.data()) && !attempted.includes(doc.id);
        });

        if (current) {
          const amount = Number(room.wagerValue || room.activeQuestion?.cost || 0);
          const wrongPenalty = behavior.isNoRisk ? 0 : amount;
          tx.set(
            roomRef.collection('players').doc(current),
            {
              score: FieldValue.increment(-wrongPenalty),
              wrongAnswers: FieldValue.increment(1),
            },
            { merge: true },
          );
        }

        if (current && !oneShot && hasRemaining) {
          tx.update(
            roomRef,
            withEngineStage(
              {
                phase: GAME_PHASE.ANSWERING,
                buzzQueue: attempted,
                currentAttemptUid: null,
                pendingAnswer: null,
                timerDeadlineAtMs: nowMs + getTimerMs(room, 'BUTTON_BLOCKING'),
                timerRemainingMs: null,
                pressBlockedUntilMs: nowMs + getTimerMs(room, 'BUTTON_BLOCKING'),
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.ANSWERING, status: room.status },
            ),
          );
        } else {
          tx.update(
            roomRef,
            withEngineStage(
              {
                phase: GAME_PHASE.BOARD_SELECT,
                currentQuestionId: null,
                activeQuestion: null,
                buzzQueue: [],
                currentAttemptUid: null,
                pendingAnswer: null,
                targetedUid: null,
                wagerValue: null,
                numericAnswers: null,
                timerDeadlineAtMs: null,
                timerRemainingMs: null,
                pressBlockedUntilMs: null,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.BOARD_SELECT, status: room.status },
            ),
          );
        }
        return;
      }

      if (room.phase === GAME_PHASE.ANSWER_REVIEW) {
        const current = String(room.currentAttemptUid || '').trim();
        const activeQuestion = room.activeQuestion || null;
        if (!current || !activeQuestion) {
          tx.update(
            roomRef,
            withEngineStage(
              {
                phase: GAME_PHASE.BOARD_SELECT,
                currentQuestionId: null,
                activeQuestion: null,
                buzzQueue: [],
                currentAttemptUid: null,
                pendingAnswer: null,
                targetedUid: null,
                wagerValue: null,
                numericAnswers: null,
                timerDeadlineAtMs: null,
                timerRemainingMs: null,
                pressBlockedUntilMs: null,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.BOARD_SELECT, status: room.status },
            ),
          );
          return;
        }

        const attempted = Array.isArray(room.buzzQueue) ? [...room.buzzQueue] : [];
        if (!attempted.includes(current)) {
          attempted.push(current);
        }
        const behavior = getQuestionBehavior(activeQuestion.kind || activeQuestion.type);
        if (room.forAllMode === true || behavior.isForAll) {
          const amount = Number(room.wagerValue || activeQuestion.cost || 0);
          const wrongPenalty = behavior.isNoRisk ? 0 : amount;
          tx.set(
            roomRef.collection('players').doc(current),
            {
              score: FieldValue.increment(-wrongPenalty),
              wrongAnswers: FieldValue.increment(1),
            },
            { merge: true },
          );
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
              withEngineStage(
                {
                  phase: GAME_PHASE.BOARD_SELECT,
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
                  forAllMode: false,
                  forAllSubmittedUids: [],
                  forAllReviewOrder: [],
                  forAllReviewIndex: 0,
                  timerDeadlineAtMs: null,
                  timerRemainingMs: null,
                  pressBlockedUntilMs: null,
                  updatedAt: FieldValue.serverTimestamp(),
                },
                { phase: GAME_PHASE.BOARD_SELECT, status: room.status },
              ),
            );
          }
          return;
        }
        const oneShot = behavior.oneShot;
        const playersSnap = await tx.get(roomRef.collection('players'));
        const hasRemaining = playersSnap.docs.some((doc) => {
          return isConnectedVoicePlayer(doc.data()) && !attempted.includes(doc.id);
        });

        const amount = Number(room.wagerValue || activeQuestion.cost || 0);
        const wrongPenalty = behavior.isNoRisk ? 0 : amount;
        tx.set(
          roomRef.collection('players').doc(current),
          {
            score: FieldValue.increment(-wrongPenalty),
            wrongAnswers: FieldValue.increment(1),
          },
          { merge: true },
        );

        if (!oneShot && hasRemaining) {
          const nowMs = Date.now();
          tx.update(
            roomRef,
            withEngineStage(
              {
                phase: GAME_PHASE.ANSWERING,
                buzzQueue: attempted,
                currentAttemptUid: null,
                pendingAnswer: null,
                appealActive: false,
                appealRequestedByUid: null,
                appealForUid: null,
                timerDeadlineAtMs: nowMs + getTimerMs(room, 'BUTTON_BLOCKING'),
                timerRemainingMs: null,
                pressBlockedUntilMs: nowMs + getTimerMs(room, 'BUTTON_BLOCKING'),
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.ANSWERING, status: room.status },
            ),
          );
        } else {
          tx.update(
            roomRef,
            withEngineStage(
              {
                phase: GAME_PHASE.BOARD_SELECT,
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
                pressBlockedUntilMs: null,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { phase: GAME_PHASE.BOARD_SELECT, status: room.status },
            ),
          );
        }
        return;
      }

      if (room.phase === GAME_PHASE.FINAL_WAGERING) {
        const eligible = Array.isArray(room.finalEligibleUids)
          ? room.finalEligibleUids
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        const playersSnap = await tx.get(roomRef.collection('players'));
        const playersByUid = new Map(
          playersSnap.docs.map((doc) => [doc.id, doc.data() || {}]),
        );
        for (const playerUid of eligible) {
          const submitted = Boolean(playersByUid.get(playerUid)?.finalWagerSubmitted);
          if (!submitted) {
            tx.set(
              roomRef.collection('players').doc(playerUid),
              {
                finalWager: 0,
                finalWagerSubmitted: true,
              },
              { merge: true },
            );
          }
        }
        const answerOrder = eligible
          .map((playerUid) => ({
            uid: playerUid,
            score: Number(playersByUid.get(playerUid)?.score || 0),
          }))
          .sort((a, b) => (a.score - b.score) || a.uid.localeCompare(b.uid))
          .map((entry) => entry.uid);
        const currentUid = answerOrder.length > 0 ? answerOrder[0] : null;

        tx.update(
          roomRef,
          withEngineStage(
            {
              phase: GAME_PHASE.FINAL_ANSWERING,
              finalAnswerOrder: answerOrder,
              finalAnswerIndex: 0,
              finalAnswerCurrentUid: currentUid,
              timerDeadlineAtMs: Date.now() + getTimerMs(room, 'FINAL_ANSWERING'),
              timerRemainingMs: null,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { phase: GAME_PHASE.FINAL_ANSWERING, status: room.status },
          ),
        );
        return;
      }

      if (room.phase === GAME_PHASE.FINAL_ANSWERING) {
        const eligible = Array.isArray(room.finalEligibleUids)
          ? room.finalEligibleUids
            .map((v) => String(v || '').trim())
            .filter((v) => v.length > 0)
          : [];
        const playersSnap = await tx.get(roomRef.collection('players'));
        let hasPending = false;
        playersSnap.docs.forEach((playerDoc) => {
          if (!eligible.includes(playerDoc.id)) {
            return;
          }
          const result = String(playerDoc.data()?.finalResult || FINAL_RESULT.PENDING);
          if (result === FINAL_RESULT.PENDING) {
            hasPending = true;
            tx.set(
              playerDoc.ref,
              { finalResult: FINAL_RESULT.NO_ANSWER },
              { merge: true },
            );
          }
        });
        if (hasPending) {
          tx.update(roomRef, {
            finalAnswerCurrentUid: null,
            finalAnswerIndex: Math.max(0, Number(room.finalAnswerOrder?.length || 0)),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        shouldRevealFinal = true;
      }

      if (room.phase === GAME_PHASE.FINAL_REVEAL) {
        shouldRevealFinal = true;
      }
    });

    if (shouldRevealFinal) {
      await revealFinalByHost(roomRef, roomId, hostUid);
    }
    await autoAdvanceGameFlowIfNeeded(roomRef);
    await logEvent(roomId, hostUid, 'timer_expire', 'Timer expired');
  }

  return {
    isFinalPhase,
    getRoundStats,
    getNextPlayableRound,
    buildFinalRoundPayload,
    revealFinalByHost,
    autoAdvanceGameFlowIfNeeded,
    autoHealAfterRosterChange,
    handleTimerExpirationByHost,
  };
}

module.exports = {
  createGameFlowEngine,
};
