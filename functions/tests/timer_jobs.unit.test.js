const test = require('node:test');
const assert = require('node:assert/strict');
const { createServerTimerTickHandler } = require('../src/game/timer_jobs');

function createRoomsQuery(docs) {
  return {
    where() {
      return this;
    },
    limit() {
      return this;
    },
    async get() {
      return { docs };
    },
  };
}

test('timer job exits early when timerAutoTick is disabled', async () => {
  let queried = false;
  const handler = createServerTimerTickHandler({
    db: {
      collection() {
        queried = true;
        return createRoomsQuery([]);
      },
    },
    GAME_STATUS: { PAUSED: 'paused' },
    isFeatureEnabled: async () => false,
    handleTimerExpirationByHost: async () => {},
  });

  const result = await handler();
  assert.equal(result, null);
  assert.equal(queried, false);
});

test('timer job processes eligible rooms and skips rooms without host', async () => {
  const calls = [];
  const docs = [
    {
      id: 'r1',
      ref: { id: 'r1-ref' },
      data: () => ({ hostUid: 'h1' }),
    },
    {
      id: 'r2',
      ref: { id: 'r2-ref' },
      data: () => ({}),
    },
    {
      id: 'r3',
      ref: { id: 'r3-ref' },
      data: () => ({ hostUid: 'h3' }),
    },
  ];
  const errors = [];
  const realError = console.error;
  console.error = (...args) => errors.push(args.join(' '));

  try {
    const handler = createServerTimerTickHandler({
      db: {
        collection() {
          return createRoomsQuery(docs);
        },
      },
      GAME_STATUS: { PAUSED: 'paused' },
      isFeatureEnabled: async () => true,
      handleTimerExpirationByHost: async (roomRef, roomId, hostUid) => {
        calls.push({ roomRef, roomId, hostUid });
        if (roomId === 'r3') {
          throw new Error('boom');
        }
      },
    });

    const result = await handler();
    assert.equal(result, null);
    assert.equal(calls.length, 2);
    assert.deepEqual(calls[0], {
      roomRef: { id: 'r1-ref' },
      roomId: 'r1',
      hostUid: 'h1',
    });
    assert.deepEqual(calls[1], {
      roomRef: { id: 'r3-ref' },
      roomId: 'r3',
      hostUid: 'h3',
    });
    assert.equal(errors.length, 1);
    assert.match(errors[0], /timer tick failed r3 boom/);
  } finally {
    console.error = realError;
  }
});
