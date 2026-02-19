const test = require('node:test');
const assert = require('node:assert/strict');
const { createCommandSupport } = require('../src/game/command_support');

class HttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function createFakeDb({
  profileByUid = {},
  featureFlags = {},
  playerRole = null,
  hostUid = 'host-1',
  roomExists = true,
} = {}) {
  let featureFlagsReads = 0;
  return {
    get featureFlagsReads() {
      return featureFlagsReads;
    },
    collection(name) {
      if (name === 'profiles') {
        return {
          doc(uid) {
            return {
              async get() {
                return {
                  data: () => profileByUid[uid] || {},
                };
              },
            };
          },
        };
      }
      if (name === 'config') {
        return {
          doc(docId) {
            assert.equal(docId, 'feature_flags');
            return {
              async get() {
                featureFlagsReads += 1;
                return {
                  data: () => featureFlags,
                };
              },
            };
          },
        };
      }
      return {
        doc() {
          return {
            async get() {
              return {
                exists: roomExists,
                data: () => ({ hostUid }),
              };
            },
            collection(subName) {
              if (subName !== 'players') {
                throw new Error('Unexpected sub collection');
              }
              return {
                doc() {
                  return {
                    async get() {
                      return {
                        data: () => ({ role: playerRole }),
                      };
                    },
                  };
                },
              };
            },
          };
        },
      };
    },
  };
}

function buildSupport(db) {
  return createCommandSupport({
    db,
    FieldValue: { serverTimestamp: () => 123 },
    functionsLib: { https: { HttpsError } },
    PLAYER_ROLE: { HOST: 'host', EDITOR: 'editor', PLAYER: 'player' },
    featureFlagsDefaults: { bulkQuestionImport: true, timerAutoTick: true },
    featureFlagsTtlMs: 30_000,
  });
}

test('requireAuth returns uid and rejects unauthenticated context', async () => {
  const support = buildSupport(createFakeDb());
  assert.equal(support.requireAuth({ auth: { uid: 'u1' } }), 'u1');
  await assert.rejects(
    async () => support.requireAuth({}),
    (error) => error.code === 'unauthenticated',
  );
});

test('requireHost validates room existence and host uid', async () => {
  const supportNotFound = buildSupport(createFakeDb({ roomExists: false }));
  await assert.rejects(
    () => supportNotFound.requireHost({ get: async () => ({ exists: false }) }, 'u1'),
    (error) => error.code === 'not-found',
  );

  const supportWrongHost = buildSupport(createFakeDb());
  await assert.rejects(
    () => supportWrongHost.requireHost({
      get: async () => ({ exists: true, data: () => ({ hostUid: 'other' }) }),
    }, 'u1'),
    (error) => error.code === 'permission-denied',
  );
});

test('assertRoomMember and canEditContent enforce role checks', async () => {
  const support = buildSupport(createFakeDb({ playerRole: 'editor' }));
  const roomRef = {
    collection() {
      return {
        doc() {
          return {
            async get() {
              return { data: () => ({ role: 'editor' }) };
            },
          };
        },
      };
    },
  };
  assert.equal(await support.assertRoomMember(roomRef, 'u1'), 'editor');
  assert.equal(support.canEditContent('host'), true);
  assert.equal(support.canEditContent('editor'), true);
  assert.equal(support.canEditContent('player'), false);

  const supportNoRole = buildSupport(createFakeDb({ playerRole: null }));
  const roomRefNoRole = {
    collection() {
      return {
        doc() {
          return {
            async get() {
              return { data: () => ({ role: null }) };
            },
          };
        },
      };
    },
  };
  await assert.rejects(
    () => supportNoRole.assertRoomMember(roomRefNoRole, 'u2'),
    (error) => error.code === 'permission-denied',
  );
});

test('isFeatureEnabled uses cache within ttl', async () => {
  const db = createFakeDb({
    featureFlags: { timerAutoTick: false, bulkQuestionImport: true },
  });
  const support = buildSupport(db);

  const realNow = Date.now;
  let now = 1000;
  Date.now = () => now;
  try {
    assert.equal(await support.isFeatureEnabled('timerAutoTick'), false);
    assert.equal(await support.isFeatureEnabled('timerAutoTick'), false);
    assert.equal(db.featureFlagsReads, 1);

    now = 1000 + 30_001;
    assert.equal(await support.isFeatureEnabled('timerAutoTick'), false);
    assert.equal(db.featureFlagsReads, 2);
  } finally {
    Date.now = realNow;
  }
});

test('logEvent uses canonical message by type and fallback for unknown type', async () => {
  const writes = [];
  const db = {
    collection(name) {
      assert.equal(name, 'rooms');
      return {
        doc(roomId) {
          return {
            collection(subName) {
              assert.equal(subName, 'events');
              return {
                async add(payload) {
                  writes.push({ roomId, payload });
                },
              };
            },
          };
        },
      };
    },
  };

  const support = createCommandSupport({
    db,
    FieldValue: { serverTimestamp: () => 123 },
    functionsLib: { https: { HttpsError } },
    PLAYER_ROLE: { HOST: 'host', EDITOR: 'editor', PLAYER: 'player' },
    featureFlagsDefaults: { bulkQuestionImport: true, timerAutoTick: true },
    featureFlagsTtlMs: 30_000,
  });

  await support.logEvent('r1', 'u1', 'pause', 'garbled text');
  await support.logEvent('r1', 'u1', 'custom_type', 'Custom message');
  await support.logEvent('r1', 'u1', 'custom_empty', '');

  assert.equal(writes.length, 3);
  assert.deepEqual(writes[0], {
    roomId: 'r1',
    payload: {
      actorUid: 'u1',
      type: 'pause',
      message: 'Game paused',
      createdAt: 123,
    },
  });
  assert.deepEqual(writes[1], {
    roomId: 'r1',
    payload: {
      actorUid: 'u1',
      type: 'custom_type',
      message: 'Custom message',
      createdAt: 123,
    },
  });
  assert.deepEqual(writes[2], {
    roomId: 'r1',
    payload: {
      actorUid: 'u1',
      type: 'custom_empty',
      message: 'custom_empty',
      createdAt: 123,
    },
  });
});
