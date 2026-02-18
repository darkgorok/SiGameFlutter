const test = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');

const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

test('gameCommand rejects unauthenticated calls', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  await assert.rejects(
    () => gameCommandHandler({ command: 'list_packs' }, {}),
    (error) => error && error.code === 'unauthenticated',
  );
});

test('gameCommand can create room in emulator', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const uid = `emu-${Date.now()}`;
  const db = admin.firestore();

  await db.collection('profiles').doc(uid).set({ nickname: 'EmuUser' });
  const result = await gameCommandHandler(
    { command: 'create_room', data: { roomName: 'Emu room' } },
    { auth: { uid } },
  );

  assert.ok(result.roomId);
  const roomSnap = await db.collection('rooms').doc(result.roomId).get();
  assert.equal(roomSnap.exists, true);
});
