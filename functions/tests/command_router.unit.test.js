const test = require('node:test');
const assert = require('node:assert/strict');
const { createCommandRouter } = require('../src/game/command_router');

class HttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const functionsLib = {
  https: { HttpsError },
};

test('command router runs meta handlers without roomId', async () => {
  const router = createCommandRouter({
    functionsLib,
    assertRoomActor: async () => 'player',
    metaCommandHandlers: {
      ping: async () => ({ ok: true }),
    },
    roomCommandHandlers: {},
    contentCommandHandlers: {},
    gameplayCommandHandlers: {},
  });

  const result = await router({
    command: 'ping',
    uid: 'u1',
    payload: {},
    roomId: '',
    roomRef: null,
  });

  assert.deepEqual(result, { ok: true });
});

test('command router requires roomId for non-meta command', async () => {
  const router = createCommandRouter({
    functionsLib,
    assertRoomActor: async () => 'player',
    metaCommandHandlers: {},
    roomCommandHandlers: {
      join_room: async () => ({ ok: true }),
    },
    contentCommandHandlers: {},
    gameplayCommandHandlers: {},
  });

  await assert.rejects(
    () => router({
      command: 'join_room',
      uid: 'u1',
      payload: {},
      roomId: '',
      roomRef: null,
    }),
    (error) => error.code === 'invalid-argument' && /roomId required/.test(error.message),
  );
});

test('command router checks room actor for gameplay commands', async () => {
  let checked = 0;
  const router = createCommandRouter({
    functionsLib,
    assertRoomActor: async () => {
      checked += 1;
      return 'player';
    },
    metaCommandHandlers: {},
    roomCommandHandlers: {},
    contentCommandHandlers: {},
    gameplayCommandHandlers: {
      buzz: async () => ({ ok: true }),
    },
  });

  const result = await router({
    command: 'buzz',
    uid: 'u1',
    payload: {},
    roomId: 'room-1',
    roomRef: {},
  });

  assert.deepEqual(result, { ok: true });
  assert.equal(checked, 1);
});

test('command router skips room actor check for join_room', async () => {
  let checked = 0;
  const router = createCommandRouter({
    functionsLib,
    assertRoomActor: async () => {
      checked += 1;
      return 'player';
    },
    metaCommandHandlers: {},
    roomCommandHandlers: {
      join_room: async () => ({ ok: true }),
    },
    contentCommandHandlers: {},
    gameplayCommandHandlers: {},
  });

  const result = await router({
    command: 'join_room',
    uid: 'u1',
    payload: {},
    roomId: 'room-1',
    roomRef: {},
  });

  assert.deepEqual(result, { ok: true });
  assert.equal(checked, 0);
});
