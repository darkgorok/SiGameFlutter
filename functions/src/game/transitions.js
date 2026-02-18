const { GAME_PHASE } = require('./constants');

function createTransitions(deps) {
  const {
    GAME_STATUS,
    withEngineStage,
    normalizeAliases,
    normalizeQuestionType,
    normalizeQuestionKind,
    getQuestionBehavior,
    isFinalPhase,
    GAME_TIMER_MS,
  } = deps;

  function getTimerMs(room, key) {
    const custom = Number(room?.rules?.timers?.[key]);
    if (Number.isFinite(custom) && custom >= 1000) {
      return Math.floor(custom);
    }
    return Number(GAME_TIMER_MS[key] || 1000);
  }

  function phaseByQuestionType(type) {
    if (type === 'cat_in_bag') return GAME_PHASE.CAT_TARGETING;
    if (type === 'wager') return GAME_PHASE.WAGER_BIDDING;
    if (type === 'closest_number') return GAME_PHASE.ANSWERING;
    return GAME_PHASE.QUESTION_REVEAL;
  }

  function pickQuestionUpdate({ roomStatus, room, chooserUid, questionId, question, nowMs }) {
    const kind = normalizeQuestionKind(question.kind || question.type);
    const behavior = getQuestionBehavior(kind);
    const type = behavior.type || normalizeQuestionType(kind);
    const phase = behavior.kind === 'for_yourself' || behavior.isForAll
      ? GAME_PHASE.ANSWERING
      : phaseByQuestionType(type);
    const stageTimer = phase === GAME_PHASE.CAT_TARGETING
      ? getTimerMs(room, 'CAT_SELECTION')
      : phase === GAME_PHASE.WAGER_BIDDING
        ? getTimerMs(room, 'WAGER_SELECTION')
        : phase === GAME_PHASE.ANSWERING
          ? getTimerMs(room, 'ANSWERING')
          : getTimerMs(room, 'QUESTION_REVEAL');

    return withEngineStage(
      {
        phase,
        currentQuestionId: questionId,
        activeQuestion: {
          id: questionId,
          theme: question.theme || 'No theme',
          text: question.text || '',
          answer: '',
          cost: Number(question.cost || 100),
          type,
          kind,
          mediaUrl: question.mediaUrl || '',
          mediaType: question.mediaType || 'none',
          aliases: normalizeAliases(question.aliases || []),
        },
        buzzQueue: behavior.kind === 'for_yourself' && chooserUid ? [chooserUid] : [],
        currentAttemptUid: behavior.kind === 'for_yourself' ? (chooserUid || null) : null,
        pendingAnswer: null,
        appealActive: false,
        appealRequestedByUid: null,
        appealForUid: null,
        targetedUid: behavior.kind === 'for_yourself' ? (chooserUid || null) : null,
        wagerValue: null,
        numericAnswers: type === 'closest_number' ? {} : null,
        forAllMode: behavior.isForAll,
        forAllSubmittedUids: [],
        forAllReviewOrder: [],
        forAllReviewIndex: 0,
        timerDeadlineAtMs: nowMs + stageTimer,
        timerRemainingMs: null,
        pressBlockedUntilMs: null,
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase, status: roomStatus },
    );
  }

  function openBuzzingUpdate({ roomStatus, room, nowMs }) {
    return withEngineStage(
      {
        phase: GAME_PHASE.ANSWERING,
        currentAttemptUid: null,
        pendingAnswer: null,
        appealActive: false,
        appealRequestedByUid: null,
        appealForUid: null,
        timerDeadlineAtMs: nowMs + getTimerMs(room, 'PRESSING'),
        timerRemainingMs: null,
        pressBlockedUntilMs: null,
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: GAME_PHASE.ANSWERING, status: roomStatus },
    );
  }

  function startGameRoomUpdate({ chooserUid }) {
    return withEngineStage(
      {
        status: GAME_STATUS.IN_GAME,
        phase: GAME_PHASE.BOARD_SELECT,
        currentRound: 1,
        chooserUid,
        pausedByUid: null,
        finalAnswer: deps.FieldValue.delete(),
        numericAnswers: null,
        appealActive: false,
        appealRequestedByUid: null,
        appealForUid: null,
        forAllMode: false,
        forAllSubmittedUids: [],
        forAllReviewOrder: [],
        forAllReviewIndex: 0,
        timerDeadlineAtMs: null,
        timerRemainingMs: null,
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: GAME_PHASE.BOARD_SELECT, status: GAME_STATUS.IN_GAME },
    );
  }

  function advanceRoundRoomUpdate({ nextRound }) {
    return withEngineStage(
      {
        currentRound: nextRound,
        phase: GAME_PHASE.BOARD_SELECT,
        status: GAME_STATUS.IN_GAME,
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: GAME_PHASE.BOARD_SELECT, status: GAME_STATUS.IN_GAME },
    );
  }

  function startFinalRoundRoomUpdate({
    finalRoundNumber,
    eligible,
    finalThemePool,
    selectedFinal,
    finalThemeDeleteOrder,
    finalThemeDeleteCandidates,
    finalThemeDeleteNeedsSelection,
    finalThemeDeleteIndex,
    finalThemeDeleteCurrentUid,
  }) {
    return withEngineStage(
      {
        status: GAME_STATUS.FINAL_ROUND,
        currentRound: finalRoundNumber,
        phase: GAME_PHASE.FINAL_SETUP,
        currentQuestionId: null,
        activeQuestion: null,
        numericAnswers: null,
        finalEligibleUids: eligible,
        finalThemePool: Array.isArray(finalThemePool) ? finalThemePool : [],
        finalThemeDeleteOrder: Array.isArray(finalThemeDeleteOrder) ? finalThemeDeleteOrder : [],
        finalThemeDeleteCandidates: Array.isArray(finalThemeDeleteCandidates)
          ? finalThemeDeleteCandidates
          : [],
        finalThemeDeleteNeedsSelection: Boolean(finalThemeDeleteNeedsSelection),
        finalThemeDeleteIndex: Number(finalThemeDeleteIndex || 0),
        finalThemeDeleteCurrentUid: finalThemeDeleteCurrentUid || null,
        finalAnswerOrder: [],
        finalAnswerIndex: 0,
        finalAnswerCurrentUid: null,
        finalRevealOrder: [],
        finalRevealIndex: 0,
        finalRevealCurrentUid: null,
        finalTheme: selectedFinal?.theme || null,
        finalQuestion: selectedFinal?.question || null,
        finalAnswer: selectedFinal?.answer || null,
        timerDeadlineAtMs: null,
        timerRemainingMs: null,
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: GAME_PHASE.FINAL_SETUP, status: GAME_STATUS.FINAL_ROUND },
    );
  }

  function setFinalQuestionRoomUpdate({ theme, question, answer }) {
    return withEngineStage(
      {
        finalTheme: String(theme || ''),
        finalQuestion: String(question || ''),
        finalAnswer: String(answer || ''),
        phase: GAME_PHASE.FINAL_SETUP,
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: GAME_PHASE.FINAL_SETUP, status: GAME_STATUS.FINAL_ROUND },
    );
  }

  function selectCatTargetUpdate({ roomStatus, room, targetUid, nowMs }) {
    return withEngineStage(
      {
        targetedUid: targetUid,
        phase: GAME_PHASE.ANSWERING,
        currentAttemptUid: targetUid,
        buzzQueue: [targetUid],
        appealActive: false,
        appealRequestedByUid: null,
        appealForUid: null,
        timerDeadlineAtMs: nowMs + getTimerMs(room, 'ANSWERING'),
        timerRemainingMs: null,
        pressBlockedUntilMs: null,
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: GAME_PHASE.ANSWERING, status: roomStatus },
    );
  }

  function setWagerAndOpenUpdate({ roomStatus, room, actorUid, safeWager, nowMs }) {
    return withEngineStage(
      {
        wagerValue: safeWager,
        phase: GAME_PHASE.ANSWERING,
        currentAttemptUid: actorUid,
        buzzQueue: [actorUid],
        appealActive: false,
        appealRequestedByUid: null,
        appealForUid: null,
        timerDeadlineAtMs: nowMs + getTimerMs(room, 'ANSWERING'),
        timerRemainingMs: null,
        pressBlockedUntilMs: null,
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: GAME_PHASE.ANSWERING, status: roomStatus },
    );
  }

  function submitAnswerUpdate({ roomStatus, room }) {
    return withEngineStage(
      {
        pendingAnswer: '[voice]',
        phase: GAME_PHASE.ANSWER_REVIEW,
        appealActive: false,
        appealRequestedByUid: null,
        appealForUid: null,
        timerDeadlineAtMs: Date.now() + getTimerMs(room, 'ANSWER_REVIEW'),
        timerRemainingMs: null,
        pressBlockedUntilMs: null,
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: GAME_PHASE.ANSWER_REVIEW, status: roomStatus },
    );
  }

  function judgeCorrectUpdate({ roomStatus, playerUid }) {
    return withEngineStage(
      {
        chooserUid: playerUid,
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
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: GAME_PHASE.BOARD_SELECT, status: roomStatus || GAME_STATUS.IN_GAME },
    );
  }

  function judgeWrongEndQuestionUpdate({ roomStatus }) {
    return withEngineStage(
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
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: GAME_PHASE.BOARD_SELECT, status: roomStatus || GAME_STATUS.IN_GAME },
    );
  }

  function judgeWrongReopenUpdate({ roomStatus, room, attempted, nowMs }) {
    return withEngineStage(
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
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: GAME_PHASE.ANSWERING, status: roomStatus || GAME_STATUS.IN_GAME },
    );
  }

  function openFinalWagersRoomUpdate({ room, nowMs }) {
    return withEngineStage(
      {
        phase: GAME_PHASE.FINAL_WAGERING,
        timerDeadlineAtMs: nowMs + getTimerMs(room, 'FINAL_WAGERING'),
        timerRemainingMs: null,
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: GAME_PHASE.FINAL_WAGERING, status: GAME_STATUS.FINAL_ROUND },
    );
  }

  function openFinalAnswersRoomUpdate({ room, nowMs }) {
    return withEngineStage(
      {
        phase: GAME_PHASE.FINAL_ANSWERING,
        timerDeadlineAtMs: nowMs + getTimerMs(room, 'FINAL_ANSWERING'),
        timerRemainingMs: null,
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: GAME_PHASE.FINAL_ANSWERING, status: GAME_STATUS.FINAL_ROUND },
    );
  }

  function pauseGameUpdate({ pausedByUid, timerDeadlineAtMs, nowMs, phase }) {
    let remaining = null;
    if (timerDeadlineAtMs) {
      remaining = Math.max(0, Number(timerDeadlineAtMs) - nowMs);
    }

    return withEngineStage(
      {
        status: GAME_STATUS.PAUSED,
        pausedByUid,
        timerRemainingMs: remaining,
        timerDeadlineAtMs: null,
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase, status: GAME_STATUS.PAUSED },
    );
  }

  function resumeGameUpdate({ room }) {
    const status = isFinalPhase(room.phase) || room.status === GAME_STATUS.FINAL_ROUND
      ? GAME_STATUS.FINAL_ROUND
      : GAME_STATUS.IN_GAME;
    const deadline = room.timerRemainingMs
      ? Date.now() + Number(room.timerRemainingMs)
      : null;

    return withEngineStage(
      {
        status,
        pausedByUid: null,
        timerDeadlineAtMs: deadline,
        timerRemainingMs: null,
        updatedAt: deps.FieldValue.serverTimestamp(),
      },
      { phase: room.phase, status },
    );
  }

  function applyCommandTransition(command, payload) {
    switch (command) {
      case 'pick_question':
        return pickQuestionUpdate(payload);
      case 'start_game':
        return startGameRoomUpdate(payload);
      case 'advance_round':
        return advanceRoundRoomUpdate(payload);
      case 'start_final_round':
        return startFinalRoundRoomUpdate(payload);
      case 'set_final_question':
        return setFinalQuestionRoomUpdate(payload);
      case 'open_buzzing':
        return openBuzzingUpdate(payload);
      case 'select_cat_target':
        return selectCatTargetUpdate(payload);
      case 'set_wager_and_open':
        return setWagerAndOpenUpdate(payload);
      case 'submit_answer':
        return submitAnswerUpdate(payload);
      case 'judge_correct':
        return judgeCorrectUpdate(payload);
      case 'judge_wrong_end':
        return judgeWrongEndQuestionUpdate(payload);
      case 'judge_wrong_reopen':
        return judgeWrongReopenUpdate(payload);
      case 'open_final_wagers':
        return openFinalWagersRoomUpdate(payload);
      case 'open_final_answers':
        return openFinalAnswersRoomUpdate(payload);
      case 'pause_game':
        return pauseGameUpdate(payload);
      case 'resume_game':
        return resumeGameUpdate(payload);
      default:
        throw new Error(`Unknown transition command: ${command}`);
    }
  }

  return {
    applyCommandTransition,
    phaseByQuestionType,
    startGameRoomUpdate,
    advanceRoundRoomUpdate,
    startFinalRoundRoomUpdate,
    setFinalQuestionRoomUpdate,
    pickQuestionUpdate,
    openBuzzingUpdate,
    selectCatTargetUpdate,
    setWagerAndOpenUpdate,
    submitAnswerUpdate,
    judgeCorrectUpdate,
    judgeWrongEndQuestionUpdate,
    judgeWrongReopenUpdate,
    openFinalWagersRoomUpdate,
    openFinalAnswersRoomUpdate,
    pauseGameUpdate,
    resumeGameUpdate,
  };
}

module.exports = {
  createTransitions,
};
