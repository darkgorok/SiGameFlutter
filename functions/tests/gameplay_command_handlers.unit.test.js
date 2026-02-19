const test = require('node:test');
const assert = require('node:assert/strict');
const { createGameplayCommandHandlers } = require('../src/game/gameplay_command_handlers');

class HttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function createHandlers({
  roomData,
  playersDocs = [],
  buildFinalRoundPayload = async () => ({
    eligible: [],
    finalRoundNumber: 2,
    finalThemePool: [],
    selectedFinal: null,
    finalThemeDeleteOrder: [],
    finalThemeDeleteCandidates: [],
    finalThemeDeleteNeedsSelection: false,
    finalThemeDeleteIndex: 0,
    finalThemeDeleteCurrentUid: null,
  }),
} = {}) {
  const playersByUid = new Map(
    playersDocs.map((doc) => [String(doc.id || ''), (doc.data && doc.data()) || {}]),
  );
  const txSets = [];
  const txUpdates = [];

  const roomRef = {
    id: 'room-1',
    collection: (name) => {
      if (name !== 'players') {
        throw new Error(`Unexpected collection: ${name}`);
      }
      return {
        _kind: 'players_collection',
        doc: (uid) => ({ _kind: 'player_doc', uid: String(uid || '') }),
      };
    },
    get: async () => ({ data: () => roomData || {} }),
    update: async () => {},
  };

  const db = {
    runTransaction: async (cb) => {
      const tx = {
        get: async (ref) => {
          if (ref === roomRef) {
            return {
              exists: true,
              data: () => roomData || {},
            };
          }
          if (ref && ref._kind === 'players_collection') {
            return { docs: playersDocs };
          }
          if (ref && ref._kind === 'player_doc') {
            return {
              exists: playersByUid.has(ref.uid),
              data: () => playersByUid.get(ref.uid) || {},
            };
          }
          throw new Error('Unknown transaction get ref');
        },
        set: (ref, data, options) => {
          txSets.push({ ref, data, options });
        },
        update: (ref, data) => {
          txUpdates.push({ ref, data });
        },
      };
      return cb(tx);
    },
  };

  const handlers = createGameplayCommandHandlers({
    db,
    FieldValue: { serverTimestamp: () => 123 },
    functionsLib: { https: { HttpsError } },
    GAME_STATUS: {
      PAUSED: 'paused',
      FINAL_ROUND: 'final_round',
      IN_GAME: 'in_game',
    },
    GAME_PHASE: {
      FINAL_WAGERING: 'final_wagering',
      FINAL_SETUP: 'final_setup',
    },
    PLAYER_ROLE: { PLAYER: 'player', SPECTATOR: 'spectator' },
    FINAL_RESULT: { PENDING: 'pending' },
    ensureVoiceRole: () => true,
    toFiniteNumber: (v) => Number(v),
    getQuestionBehavior: () => ({ type: 'normal' }),
    getPlayerRole: () => 'player',
    requireHost: async () => {},
    getRoundStats: async () => ({ maxRound: 1, unusedRounds: [1] }),
    getNextPlayableRound: () => null,
    buildFinalRoundPayload,
    revealFinalByHost: async () => {},
    autoAdvanceGameFlowIfNeeded: async () => {},
    handleTimerExpirationByHost: async () => {},
    logEvent: async () => {},
    transitions: { applyCommandTransition: () => ({}) },
    withEngineStage: (x) => x,
    GAME_TIMER_MS: {},
  });

  return { handlers, roomRef, txSets, txUpdates };
}

test('open_final_answers rejects when final has no eligible players', async () => {
  const { handlers, roomRef } = createHandlers({
    roomData: {
      phase: 'final_wagering',
      status: 'final_round',
      finalEligibleUids: [],
    },
  });

  await assert.rejects(
    () => handlers.open_final_answers({ uid: 'host-1', roomId: 'room-1', roomRef }),
    (error) =>
      error instanceof HttpsError &&
      error.code === 'failed-precondition' &&
      String(error.message).includes('No eligible players'),
  );
});

test('open_final_wagers rejects when final has no eligible players', async () => {
  const { handlers, roomRef } = createHandlers({
    roomData: {
      phase: 'final_setup',
      status: 'final_round',
      finalTheme: 'Theme',
      finalQuestion: 'Question',
      finalEligibleUids: [],
    },
  });

  await assert.rejects(
    () => handlers.open_final_wagers({ uid: 'host-1', roomId: 'room-1', roomRef }),
    (error) =>
      error instanceof HttpsError &&
      error.code === 'failed-precondition' &&
      String(error.message).includes('No eligible players'),
  );
});

test('start_final_round rejects when payload has no eligible players', async () => {
  const { handlers, roomRef } = createHandlers({
    roomData: {
      phase: 'board_select',
      status: 'in_game',
      currentRound: 2,
    },
    buildFinalRoundPayload: async () => ({
      eligible: [],
      finalRoundNumber: 3,
      finalThemePool: ['Theme'],
      selectedFinal: null,
      finalThemeDeleteOrder: [],
      finalThemeDeleteCandidates: [],
      finalThemeDeleteNeedsSelection: false,
      finalThemeDeleteIndex: 0,
      finalThemeDeleteCurrentUid: null,
    }),
  });

  await assert.rejects(
    () => handlers.start_final_round({ uid: 'host-1', roomId: 'room-1', roomRef }),
    (error) =>
      error instanceof HttpsError &&
      error.code === 'failed-precondition' &&
      String(error.message).includes('No eligible players'),
  );
});

test('open_final_answers rejects when not all eligible wagers are submitted', async () => {
  const { handlers, roomRef } = createHandlers({
    roomData: {
      phase: 'final_wagering',
      status: 'final_round',
      finalEligibleUids: ['p1', 'p2'],
    },
    playersDocs: [
      { id: 'p1', data: () => ({ finalWagerSubmitted: true, score: 200 }) },
      { id: 'p2', data: () => ({ finalWagerSubmitted: false, score: 100 }) },
    ],
  });

  await assert.rejects(
    () => handlers.open_final_answers({ uid: 'host-1', roomId: 'room-1', roomRef }),
    (error) =>
      error instanceof HttpsError &&
      error.code === 'failed-precondition' &&
      String(error.message).includes('Not all final wagers are submitted'),
  );
});

test('open_final_answers builds answer order by score and resets final answer fields', async () => {
  const { handlers, roomRef, txSets, txUpdates } = createHandlers({
    roomData: {
      phase: 'final_wagering',
      status: 'final_round',
      finalEligibleUids: ['p1', 'p2', 'p3'],
    },
    playersDocs: [
      { id: 'p1', data: () => ({ finalWagerSubmitted: true, score: 300 }) },
      { id: 'p2', data: () => ({ finalWagerSubmitted: true, score: 100 }) },
      { id: 'p3', data: () => ({ finalWagerSubmitted: true, score: 100 }) },
    ],
  });

  await handlers.open_final_answers({ uid: 'host-1', roomId: 'room-1', roomRef });

  assert.equal(txSets.length, 3);
  for (const setCall of txSets) {
    assert.equal(setCall.data.finalAnswerSubmitted, false);
    assert.equal(setCall.data.finalAnswerText, null);
  }

  assert.equal(txUpdates.length, 1);
  const updatePayload = txUpdates[0].data || {};
  assert.deepEqual(updatePayload.finalAnswerOrder, ['p2', 'p3', 'p1']);
  assert.equal(updatePayload.finalAnswerIndex, 0);
  assert.equal(updatePayload.finalAnswerCurrentUid, 'p2');
});
