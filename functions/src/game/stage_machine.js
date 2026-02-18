const ENGINE_STAGE = {
  BEGIN: 'begin',
  GAME_THEMES: 'game_themes',
  ROUND: 'round',
  SELECTING_QUESTION: 'selecting_question',
  QUESTION_TYPE: 'question_type',
  QUESTION: 'question',
  END_ROUND: 'end_round',
  END_GAME: 'end_game',
  NONE: 'none',
};

function resolveEngineStage({ phase, status }) {
  if (phase === 'lobby' || status === 'lobby') {
    return ENGINE_STAGE.BEGIN;
  }

  if (phase === 'board_select') {
    return ENGINE_STAGE.SELECTING_QUESTION;
  }

  if (
    phase === 'question_reveal' ||
    phase === 'cat_targeting' ||
    phase === 'wager_bidding'
  ) {
    return ENGINE_STAGE.QUESTION_TYPE;
  }

  if (phase === 'answering' || phase === 'answer_review') {
    return ENGINE_STAGE.QUESTION;
  }

  if (
    phase === 'final_setup' ||
    phase === 'final_wagering' ||
    phase === 'final_answering' ||
    phase === 'final_reveal'
  ) {
    return ENGINE_STAGE.ROUND;
  }

  if (phase === 'game_over' || status === 'completed') {
    return ENGINE_STAGE.END_GAME;
  }

  if (status === 'in_game' || status === 'final_round') {
    return ENGINE_STAGE.ROUND;
  }

  return ENGINE_STAGE.NONE;
}

function withEngineStage(update, roomLike) {
  return {
    ...update,
    engineStage: resolveEngineStage(roomLike),
  };
}

module.exports = {
  ENGINE_STAGE,
  resolveEngineStage,
  withEngineStage,
};
