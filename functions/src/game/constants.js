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
  FINAL_REVEAL: 'final_reveal',
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

const GAME_TIMER_MS = {
  QUESTION_REVEAL: 20_000,
  CAT_SELECTION: 30_000,
  WAGER_SELECTION: 30_000,
  PRESSING: 5_000,
  BUTTON_BLOCKING: 3_000,
  ANSWERING: 25_000,
  ANSWER_REVIEW: 7_000,
  FINAL_WAGERING: 45_000,
  FINAL_ANSWERING: 45_000,
  FINAL_REVEAL_STEP: 3_000,
};

module.exports = {
  GAME_STATUS,
  GAME_PHASE,
  PLAYER_ROLE,
  FINAL_RESULT,
  ALLOWED_JOIN_ROLES,
  GAME_TIMER_MS,
};
