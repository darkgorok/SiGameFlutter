const {
  GAME_STATUS,
  GAME_PHASE,
  PLAYER_ROLE,
  FINAL_RESULT,
  ALLOWED_JOIN_ROLES,
  GAME_TIMER_MS,
} = require('./constants');
const {
  normalizeAliases,
  ensureVoiceRole,
  toFiniteNumber,
  normalizeQuestionType,
  normalizeQuestionKind,
  getQuestionBehavior,
} = require('./utils');
const { createGameFlowEngine } = require('./flow_engine');
const { createTransitions } = require('./transitions');
const { createGameplayCommandHandlers } = require('./gameplay_command_handlers');
const { createRoomCommandHandlers } = require('./room_command_handlers');
const { createContentCommandHandlers } = require('./content_command_handlers');
const { createMetaCommandHandlers } = require('./meta_command_handlers');
const { createCommandSupport } = require('./command_support');
const { createCommandRouter } = require('./command_router');
const { createGameCommandHandler } = require('./game_command_handler');
const { createServerTimerTickHandler } = require('./timer_jobs');
const {
  ENGINE_STAGE,
  withEngineStage,
} = require('./stage_machine');

const FEATURE_FLAGS_DEFAULTS = {
  bulkQuestionImport: true,
  timerAutoTick: true,
};
const FEATURE_FLAGS_TTL_MS = 30_000;

function createGameBootstrap({ db, FieldValue, functionsLib }) {
  const {
    getProfile,
    getPlayerRole,
    assertRoomMember,
    assertRoomActor,
    canEditContent,
    logEvent,
    isFeatureEnabled,
    logCommandTelemetry,
    requireAuth,
    requireHost,
  } = createCommandSupport({
    db,
    FieldValue,
    functionsLib,
    PLAYER_ROLE,
    featureFlagsDefaults: FEATURE_FLAGS_DEFAULTS,
    featureFlagsTtlMs: FEATURE_FLAGS_TTL_MS,
  });

  const gameFlow = createGameFlowEngine({
    db,
    FieldValue,
    functionsLib,
    GAME_STATUS,
    GAME_PHASE,
    PLAYER_ROLE,
    FINAL_RESULT,
    withEngineStage,
    ensureVoiceRole,
    toFiniteNumber,
    getQuestionBehavior,
    logEvent,
    requireHost,
    GAME_TIMER_MS,
  });

  const {
    isFinalPhase,
    getRoundStats,
    getNextPlayableRound,
    buildFinalRoundPayload,
    revealFinalByHost,
    autoAdvanceGameFlowIfNeeded,
    autoHealAfterRosterChange,
    handleTimerExpirationByHost,
  } = gameFlow;

  const transitions = createTransitions({
    GAME_STATUS,
    withEngineStage,
    normalizeAliases,
    normalizeQuestionType,
    normalizeQuestionKind,
    getQuestionBehavior,
    isFinalPhase,
    FieldValue,
    GAME_TIMER_MS,
  });

  const gameplayCommandHandlers = createGameplayCommandHandlers({
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
  });

  const roomCommandHandlers = createRoomCommandHandlers({
    db,
    FieldValue,
    functionsLib,
    PLAYER_ROLE,
    FINAL_RESULT,
    ALLOWED_JOIN_ROLES,
    getProfile,
    requireHost,
    autoHealAfterRosterChange,
    logEvent,
    GAME_TIMER_MS,
  });

  const contentCommandHandlers = createContentCommandHandlers({
    db,
    FieldValue,
    functionsLib,
    PLAYER_ROLE,
    normalizeAliases,
    normalizeQuestionType,
    normalizeQuestionKind,
    requireHost,
    assertRoomMember,
    canEditContent,
    isFeatureEnabled,
    logEvent,
  });

  const metaCommandHandlers = createMetaCommandHandlers({
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
  });

  const routeCommand = createCommandRouter({
    functionsLib,
    assertRoomActor,
    metaCommandHandlers,
    roomCommandHandlers,
    contentCommandHandlers,
    gameplayCommandHandlers,
  });

  const gameCommandHandler = createGameCommandHandler({
    db,
    functionsLib,
    requireAuth,
    logCommandTelemetry,
    routeCommand,
  });

  const serverTimerTickHandler = createServerTimerTickHandler({
    db,
    GAME_STATUS,
    isFeatureEnabled,
    handleTimerExpirationByHost,
  });

  return {
    gameCommandHandler,
    serverTimerTickHandler,
  };
}

module.exports = {
  createGameBootstrap,
};
