const test = require('node:test');
const assert = require('node:assert/strict');
const { createGameCommandHandler } = require('../src/game/game_command_handler');

class HttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const functionsLib = {
  https: { HttpsError },
};

test('game command handler passes parsed args to router and returns result', async () => {
  const calls = [];
  const handler = createGameCommandHandler({
    db: {
      collection: () => ({
        doc: (id) => ({ id }),
      }),
    },
    functionsLib,
    requireAuth: () => 'uid-1',
    logCommandTelemetry: () => {},
    routeCommand: async (args) => {
      calls.push(args);
      return { ok: true };
    },
  });

  const result = await handler(
    { command: 'join_room', roomId: 'room-1', data: { x: 1 } },
    { auth: { uid: 'uid-1' } },
  );

  assert.deepEqual(result, { ok: true });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].command, 'join_room');
  assert.equal(calls[0].uid, 'uid-1');
  assert.equal(calls[0].roomId, 'room-1');
  assert.equal(calls[0].roomRef.id, 'room-1');
});

test('game command handler logs failed telemetry on command validation error', async () => {
  const telemetry = [];
  const handler = createGameCommandHandler({
    db: {
      collection: () => ({
        doc: (id) => ({ id }),
      }),
    },
    functionsLib,
    requireAuth: () => 'uid-1',
    logCommandTelemetry: (payload) => telemetry.push(payload),
    routeCommand: async () => ({ ok: true }),
  });

  await assert.rejects(
    () => handler({ command: '' }, { auth: { uid: 'uid-1' } }),
    (error) => error.code === 'invalid-argument',
  );

  assert.equal(telemetry.length, 1);
  assert.equal(telemetry[0].ok, false);
  assert.equal(telemetry[0].errorCode, 'invalid-argument');
});
