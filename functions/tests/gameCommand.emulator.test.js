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
  const room = roomSnap.data() || {};
  assert.equal(Boolean(room.rules?.falseStartEnabled), false);
  assert.equal(Boolean(room.rules?.useAppeals), false);
  assert.ok(Number(room.rules?.timers?.ANSWERING || 0) > 0);
});

test('host can update room rules and false-start enables buzzing in question_reveal', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();
  const hostUid = `host-rules-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostRules' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1Rules' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'RulesRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(hostUid, 'add_question', {
    theme: 'Rules',
    text: 'False start test',
    answer: 'A',
    cost: 100,
    round: 1,
    type: 'normal',
    mediaType: 'none',
  }, roomId);
  await call(hostUid, 'start_game', {}, roomId);
  const qSnap = await roomRef.collection('questions').limit(1).get();
  const qId = qSnap.docs[0].id;
  await call(hostUid, 'pick_question', { questionId: qId }, roomId);

  await assert.rejects(
    () => call(p1Uid, 'buzz', {}, roomId),
    (error) => error && error.code === 'failed-precondition',
  );

  await call(hostUid, 'update_room_rules', {
    falseStartEnabled: true,
    useAppeals: true,
    timers: { ANSWERING: 7000, PRESSING: 6000 },
  }, roomId);

  const roomAfterRules = (await roomRef.get()).data() || {};
  assert.equal(Boolean(roomAfterRules.rules?.falseStartEnabled), true);
  assert.equal(Boolean(roomAfterRules.rules?.useAppeals), true);
  assert.equal(Number(roomAfterRules.rules?.timers?.ANSWERING || 0), 7000);
  assert.equal(Number(roomAfterRules.rules?.timers?.PRESSING || 0), 6000);

  await call(p1Uid, 'buzz', {}, roomId);
  const roomAfterBuzz = (await roomRef.get()).data() || {};
  assert.equal(String(roomAfterBuzz.phase), 'answering');
  assert.equal(String(roomAfterBuzz.currentAttemptUid), p1Uid);
  assert.ok(Number(roomAfterBuzz.timerDeadlineAtMs || 0) > Date.now());
});

test('join_room requires valid password for protected room', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-pass-${Date.now()}`;
  const guestUid = `${hostUid}-guest`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostPass' }),
    db.collection('profiles').doc(guestUid).set({ nickname: 'GuestPass' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(
    hostUid,
    'create_room',
    { roomName: 'ProtectedRoom', password: 'secret123' },
  );
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  const room = (await roomRef.get()).data() || {};
  assert.equal(Boolean(room.passwordProtected), true);
  assert.equal(Boolean(room.hasPassword), true);
  const security = (await roomRef.collection('meta').doc('security').get()).data() || {};
  assert.equal(typeof security.passwordHash, 'string');
  assert.ok(String(security.passwordHash).length > 0);

  await assert.rejects(
    () => call(guestUid, 'join_room', { role: 'player' }, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
  await assert.rejects(
    () => call(guestUid, 'join_room', { role: 'player', password: 'wrong' }, roomId),
    (error) => error && error.code === 'permission-denied',
  );

  await call(guestUid, 'join_room', { role: 'player', password: 'secret123' }, roomId);
  const guest = (await roomRef.collection('players').doc(guestUid).get()).data() || {};
  assert.equal(String(guest.role), 'player');
  assert.equal(Boolean(guest.connected), true);
});

test('non-member cannot execute gameplay command in room', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-guard-${Date.now()}`;
  const outsiderUid = `${hostUid}-outsider`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostGuard' }),
    db.collection('profiles').doc(outsiderUid).set({ nickname: 'OutsiderGuard' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'GuardRoom' });
  const roomId = create.roomId;

  await assert.rejects(
    () => call(outsiderUid, 'buzz', {}, roomId),
    (error) => error && error.code === 'permission-denied',
  );
});

test('upsert_profile enforces unique nickname (case-insensitive)', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const uid1 = `profile-unique-${Date.now()}-1`;
  const uid2 = `profile-unique-${Date.now()}-2`;
  await Promise.all([
    db.collection('profiles').doc(uid1).set({ nickname: 'U1' }),
    db.collection('profiles').doc(uid2).set({ nickname: 'U2' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  await call(uid1, 'upsert_profile', { nickname: 'UniqueNick', avatarUrl: '' });
  await assert.rejects(
    () => call(uid2, 'upsert_profile', { nickname: 'uniquenick', avatarUrl: '' }),
    (error) => error && error.code === 'already-exists',
  );

  await call(uid2, 'upsert_profile', { nickname: 'AnotherNick', avatarUrl: '' });
  const p2 = (await db.collection('profiles').doc(uid2).get()).data() || {};
  assert.equal(String(p2.nickname), 'AnotherNick');
});

test('add_question persists answer field', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();
  const hostUid = `host-answer-persist-${Date.now()}`;
  await db.collection('profiles').doc(hostUid).set({ nickname: 'HostAnswerPersist' });

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'AnswerPersist' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(
    hostUid,
    'add_question',
    {
      theme: 'Persist',
      text: 'What is persisted?',
      answer: 'Answer42',
      cost: 100,
      round: 1,
      type: 'normal',
      mediaType: 'none',
    },
    roomId,
  );

  const qSnap = await roomRef.collection('questions').limit(1).get();
  const q = qSnap.docs[0].data();
  assert.equal(String(q.answer), 'Answer42');
});

test('add_questions_bulk validates required question fields', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();
  const hostUid = `host-bulk-validate-${Date.now()}`;
  await db.collection('profiles').doc(hostUid).set({ nickname: 'HostBulkValidate' });

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'BulkValidate' });
  const roomId = create.roomId;

  await assert.rejects(
    () => call(
      hostUid,
      'add_questions_bulk',
      {
        questions: [
          {
            theme: 'Broken',
            text: 'No answer here',
            cost: 100,
            round: 1,
            type: 'normal',
            mediaType: 'none',
          },
        ],
      },
      roomId,
    ),
    (error) => error && error.code === 'invalid-argument',
  );
});

test('update_question allows editor to edit unused question', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();
  const hostUid = `host-update-question-${Date.now()}`;
  const editorUid = `${hostUid}-editor`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostUpdateQuestion' }),
    db.collection('profiles').doc(editorUid).set({ nickname: 'EditorUpdateQuestion' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'UpdateQuestionRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(editorUid, 'join_room', { role: 'editor' }, roomId);

  await call(
    hostUid,
    'add_question',
    {
      theme: 'Before',
      text: 'Before text',
      answer: 'Before answer',
      cost: 100,
      round: 1,
      type: 'normal',
      mediaType: 'none',
      aliases: ['first'],
    },
    roomId,
  );
  const qSnap = await roomRef.collection('questions').limit(1).get();
  const qId = qSnap.docs[0].id;

  await call(
    editorUid,
    'update_question',
    {
      questionId: qId,
      theme: 'After',
      text: 'After text',
      answer: 'After answer',
      cost: 500,
      round: 2,
      type: 'stake_all',
      mediaType: 'audio',
      mediaUrl: 'https://example.com/audio.mp3',
      aliases: ['dup', 'dup', 'final'],
    },
    roomId,
  );

  const q = (await roomRef.collection('questions').doc(qId).get()).data() || {};
  assert.equal(String(q.theme), 'After');
  assert.equal(String(q.text), 'After text');
  assert.equal(String(q.answer), 'After answer');
  assert.equal(Number(q.cost || 0), 500);
  assert.equal(Number(q.round || 0), 2);
  assert.equal(String(q.kind), 'stake_all');
  assert.equal(String(q.type), 'wager');
  assert.equal(String(q.mediaType), 'audio');
  assert.equal(String(q.mediaUrl), 'https://example.com/audio.mp3');
  assert.deepEqual(Array.isArray(q.aliases) ? q.aliases : [], ['dup', 'final']);
});

test('delete_question removes unused but blocks used question deletion', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();
  const hostUid = `host-delete-question-${Date.now()}`;
  await db.collection('profiles').doc(hostUid).set({ nickname: 'HostDeleteQuestion' });

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'DeleteQuestionRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(hostUid, 'add_questions_bulk', {
    questions: [
      {
        theme: 'Delete',
        text: 'Used question',
        answer: 'A',
        cost: 100,
        round: 1,
        type: 'normal',
        mediaType: 'none',
      },
      {
        theme: 'Delete',
        text: 'Unused question',
        answer: 'B',
        cost: 200,
        round: 1,
        type: 'normal',
        mediaType: 'none',
      },
    ],
  }, roomId);

  const beforeSnap = await roomRef.collection('questions').get();
  const usedQ = beforeSnap.docs.find((doc) => String(doc.data()?.text || '') === 'Used question');
  const unusedQ = beforeSnap.docs.find((doc) => String(doc.data()?.text || '') === 'Unused question');
  assert.ok(usedQ && unusedQ);

  await call(hostUid, 'delete_question', { questionId: unusedQ.id }, roomId);
  const deletedSnap = await roomRef.collection('questions').doc(unusedQ.id).get();
  assert.equal(deletedSnap.exists, false);

  await call(hostUid, 'start_game', {}, roomId);
  await call(hostUid, 'pick_question', { questionId: usedQ.id }, roomId);

  await assert.rejects(
    () => call(hostUid, 'delete_question', { questionId: usedQ.id }, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
});

test('pack save/apply preserves all question and media fields', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-pack-roundtrip-${Date.now()}`;
  await db.collection('profiles').doc(hostUid).set({ nickname: 'HostPackRoundtrip' });

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const source = await call(hostUid, 'create_room', { roomName: 'PackSource' });
  const sourceRoomId = source.roomId;
  const sourceRoomRef = db.collection('rooms').doc(sourceRoomId);

  const sourceQuestions = [
    {
      theme: 'Roundtrip Theme A',
      text: 'Normal question',
      answer: 'Normal answer',
      cost: 100,
      round: 1,
      type: 'normal',
      mediaType: 'image',
      mediaUrl: 'https://cdn.example.com/normal.png',
      aliases: ['normal', 'n'],
    },
    {
      theme: 'Roundtrip Theme B',
      text: 'Cat question',
      answer: 'Cat answer',
      cost: 200,
      round: 1,
      type: 'cat_in_bag',
      mediaType: 'audio',
      mediaUrl: 'https://cdn.example.com/cat.mp3',
      aliases: ['cat'],
    },
    {
      theme: 'Roundtrip Theme C',
      text: 'Wager question',
      answer: 'Wager answer',
      cost: 300,
      round: 2,
      type: 'wager',
      mediaType: 'video',
      mediaUrl: 'https://cdn.example.com/wager.mp4',
      aliases: ['wager'],
    },
    {
      theme: 'Roundtrip Theme D',
      text: 'Closest number question',
      answer: '42',
      cost: 400,
      round: 2,
      type: 'closest_number',
      mediaType: 'none',
      mediaUrl: '',
      aliases: [],
    },
  ];

  await call(hostUid, 'add_questions_bulk', { questions: sourceQuestions }, sourceRoomId);
  const saved = await call(
    hostUid,
    'save_pack',
    { name: `RoundtripPack-${Date.now()}` },
    sourceRoomId,
  );
  const packId = String(saved.packId || '');
  assert.ok(packId.length > 0);

  const target = await call(hostUid, 'create_room', { roomName: 'PackTarget' });
  const targetRoomId = target.roomId;
  const targetRoomRef = db.collection('rooms').doc(targetRoomId);
  await call(hostUid, 'apply_pack', { packId }, targetRoomId);

  const importedSnap = await targetRoomRef.collection('questions').get();
  assert.equal(importedSnap.size, sourceQuestions.length);

  const normalize = (q) => ({
    theme: String(q.theme || ''),
    text: String(q.text || ''),
    answer: String(q.answer || ''),
    cost: Number(q.cost || 0),
    round: Number(q.round || 0),
    type: String(q.type || ''),
    mediaType: String(q.mediaType || 'none'),
    mediaUrl: String(q.mediaUrl || ''),
    aliases: Array.isArray(q.aliases)
      ? [...q.aliases].map((v) => String(v || '')).sort()
      : [],
  });

  const expected = sourceQuestions.map(normalize).sort((a, b) => a.text.localeCompare(b.text));
  const actual = importedSnap.docs
    .map((doc) => normalize(doc.data() || {}))
    .sort((a, b) => a.text.localeCompare(b.text));
  assert.deepEqual(actual, expected);

  const sourceSnap = await sourceRoomRef.collection('questions').get();
  assert.equal(sourceSnap.size, sourceQuestions.length);
});

test('final setup supports deleting final themes until one remains', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinal' });
  await db.collection('profiles').doc(p1Uid).set({ nickname: 'P1' });
  await db.collection('profiles').doc(p2Uid).set({ nickname: 'P2' });

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalDelete' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);

  await roomRef.collection('questions').add({
    theme: 'Theme A',
    text: 'A Q',
    answer: 'A',
    cost: 100,
    round: 1,
    type: 'normal',
    used: false,
    createdBy: hostUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await roomRef.collection('questions').add({
    theme: 'Theme B',
    text: 'B Q',
    answer: 'B',
    cost: 100,
    round: 1,
    type: 'normal',
    used: false,
    createdBy: hostUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await roomRef.update({
    status: 'final_round',
    phase: 'final_setup',
    finalThemePool: ['Theme A', 'Theme B'],
    finalTheme: null,
    finalQuestion: null,
    finalAnswer: null,
    finalEligibleUids: [p1Uid, p2Uid],
    finalThemeDeleteOrder: [p1Uid, p2Uid],
    finalThemeDeleteCandidates: [p1Uid, p2Uid],
    finalThemeDeleteNeedsSelection: true,
    finalThemeDeleteIndex: -1,
    finalThemeDeleteCurrentUid: null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await assert.rejects(
    () => call(p2Uid, 'delete_final_theme', { theme: 'Theme A' }, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
  await assert.rejects(
    () => call(p1Uid, 'select_final_theme_deleter', { targetUid: p1Uid }, roomId),
    (error) => error && error.code === 'permission-denied',
  );
  await call(hostUid, 'select_final_theme_deleter', { targetUid: p1Uid }, roomId);

  await call(p1Uid, 'delete_final_theme', { theme: 'Theme A' }, roomId);
  const room = (await roomRef.get()).data();
  assert.deepEqual(room.finalThemePool, ['Theme B']);
  assert.equal(room.finalTheme, 'Theme B');
  assert.equal(room.finalQuestion, 'B Q');
  assert.equal(room.finalAnswer, 'B');
  assert.equal(room.finalThemeDeleteCurrentUid, null);
  assert.equal(room.finalThemeDeleteNeedsSelection, false);

  await assert.rejects(
    () => call(hostUid, 'delete_final_theme', { theme: 'Theme B' }, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
});

test('full game flow: lobby -> final reveal -> game_over', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-${Date.now()}`;
  const player1Uid = `${hostUid}-p1`;
  const player2Uid = `${hostUid}-p2`;

  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'Host' }),
    db.collection('profiles').doc(player1Uid).set({ nickname: 'PlayerOne' }),
    db.collection('profiles').doc(player2Uid).set({ nickname: 'PlayerTwo' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FullFlow' });
  const roomId = create.roomId;
  assert.ok(roomId);
  const roomRef = db.collection('rooms').doc(roomId);

  const readRoom = async () => {
    const snap = await roomRef.get();
    return snap.data();
  };
  const readPlayer = async (uid) => {
    const snap = await roomRef.collection('players').doc(uid).get();
    return snap.data();
  };

  await call(player1Uid, 'join_room', { role: 'player' }, roomId);
  await call(player2Uid, 'join_room', { role: 'player' }, roomId);

  await call(
    hostUid,
    'add_questions_bulk',
    {
      questions: [
        {
          theme: 'General image',
          text: 'Normal question',
          answer: '4',
          cost: 100,
          round: 1,
          type: 'normal',
          mediaUrl: 'https://cdn.example.com/normal.png',
          mediaType: 'image',
          aliases: ['four'],
        },
        {
          theme: 'Cat audio',
          text: 'Cat question',
          answer: 'cat',
          cost: 200,
          round: 1,
          type: 'cat_in_bag',
          mediaUrl: 'https://cdn.example.com/cat.mp3',
          mediaType: 'audio',
          aliases: ['kitty'],
        },
        {
          theme: 'Wager video',
          text: 'Wager question',
          answer: 'wager',
          cost: 300,
          round: 1,
          type: 'wager',
          mediaUrl: 'https://cdn.example.com/wager.mp4',
          mediaType: 'video',
          aliases: ['bet'],
        },
        {
          theme: 'Closest none',
          text: 'Closest number question',
          answer: '50',
          cost: 400,
          round: 1,
          type: 'closest_number',
          mediaUrl: '',
          mediaType: 'none',
          aliases: [],
        },
      ],
    },
    roomId,
  );

  await call(hostUid, 'start_game', {}, roomId);
  let room = await readRoom();
  assert.equal(room.status, 'in_game');
  assert.equal(room.phase, 'board_select');
  assert.equal(room.currentRound, 1);
  assert.equal(room.engineStage, 'selecting_question');

  const questionSnaps = await roomRef.collection('questions').get();
  const questionsByType = new Map(
    questionSnaps.docs.map((doc) => [String(doc.data().type), { id: doc.id, ...doc.data() }]),
  );
  assert.equal(questionsByType.size, 4);

  const seenTypes = new Set();
  const seenMediaTypes = new Set();

  await call(hostUid, 'pick_question', { questionId: questionsByType.get('normal').id }, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'question_reveal');
  assert.equal(room.engineStage, 'question_type');
  assert.equal(room.activeQuestion.type, 'normal');
  assert.equal(room.activeQuestion.mediaType, 'image');
  assert.equal(room.activeQuestion.mediaUrl, 'https://cdn.example.com/normal.png');
  seenTypes.add(room.activeQuestion.type);
  seenMediaTypes.add(room.activeQuestion.mediaType);

  await call(hostUid, 'open_buzzing', {}, roomId);
  await call(player1Uid, 'buzz', {}, roomId);
  await call(player1Uid, 'submit_answer', {}, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'answer_review');
  assert.equal(room.engineStage, 'question');
  await call(hostUid, 'judge_answer', { correct: true }, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'board_select');
  assert.equal(room.engineStage, 'selecting_question');
  assert.equal(room.chooserUid, player1Uid);

  await call(hostUid, 'pick_question', { questionId: questionsByType.get('cat_in_bag').id }, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'cat_targeting');
  assert.equal(room.activeQuestion.type, 'cat_in_bag');
  assert.equal(room.activeQuestion.mediaType, 'audio');
  assert.equal(room.activeQuestion.mediaUrl, 'https://cdn.example.com/cat.mp3');
  seenTypes.add(room.activeQuestion.type);
  seenMediaTypes.add(room.activeQuestion.mediaType);

  await call(hostUid, 'select_cat_target', { targetUid: player2Uid }, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'answering');
  assert.equal(room.currentAttemptUid, player2Uid);
  await call(player2Uid, 'submit_answer', {}, roomId);
  await call(hostUid, 'judge_answer', { correct: false }, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'board_select');

  await call(hostUid, 'pick_question', { questionId: questionsByType.get('wager').id }, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'wager_bidding');
  assert.equal(room.activeQuestion.type, 'wager');
  assert.equal(room.activeQuestion.mediaType, 'video');
  assert.equal(room.activeQuestion.mediaUrl, 'https://cdn.example.com/wager.mp4');
  seenTypes.add(room.activeQuestion.type);
  seenMediaTypes.add(room.activeQuestion.mediaType);

  await assert.rejects(
    () => call(player2Uid, 'set_wager_and_open', { wager: 150 }, roomId),
    (error) => error && error.code === 'permission-denied',
  );
  await call(hostUid, 'set_wager_and_open', { wager: 300 }, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'answering');
  assert.equal(room.currentAttemptUid, player1Uid);
  assert.equal(room.wagerValue, 100);
  await call(player1Uid, 'submit_answer', {}, roomId);
  await call(hostUid, 'judge_answer', { correct: false }, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'board_select');

  await call(hostUid, 'pick_question', { questionId: questionsByType.get('closest_number').id }, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'answering');
  assert.equal(room.activeQuestion.type, 'closest_number');
  assert.equal(room.activeQuestion.mediaType, 'none');
  assert.equal(room.activeQuestion.mediaUrl, '');
  seenTypes.add(room.activeQuestion.type);
  seenMediaTypes.add(room.activeQuestion.mediaType);

  await call(player1Uid, 'submit_numeric_answer', { value: 0 }, roomId);
  await call(player2Uid, 'submit_numeric_answer', { value: 60 }, roomId);
  await roomRef.update({ timerDeadlineAtMs: Date.now() - 1 });
  await call(hostUid, 'handle_timer_expiration', {}, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'final_setup');
  assert.equal(room.engineStage, 'round');
  assert.ok(Number(room.currentRound) >= 2);
  assert.equal(room.status, 'final_round');
  assert.equal(room.currentQuestionId, null);
  assert.ok(Array.isArray(room.finalEligibleUids));
  let p1 = await readPlayer(player1Uid);
  let p2 = await readPlayer(player2Uid);
  const positiveEligible = [
    ...(p1.score > 0 ? [player1Uid] : []),
    ...(p2.score > 0 ? [player2Uid] : []),
  ].sort();
  if (positiveEligible.length > 0) {
    assert.deepEqual([...room.finalEligibleUids].sort(), positiveEligible);
  } else {
    assert.ok(room.finalEligibleUids.length >= 1);
  }

  assert.deepEqual(
    [...seenTypes].sort(),
    ['cat_in_bag', 'closest_number', 'normal', 'wager'],
  );
  assert.deepEqual(
    [...seenMediaTypes].sort(),
    ['audio', 'image', 'none', 'video'],
  );

  const p2BeforeManual = p2.score;
  await call(hostUid, 'apply_score', { targetUid: player2Uid, delta: 500 }, roomId);
  p2 = await readPlayer(player2Uid);
  assert.equal(p2.score, p2BeforeManual + 500);

  await call(hostUid, 'start_final_round', {}, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'final_setup');
  assert.ok(Array.isArray(room.finalEligibleUids));
  assert.ok(room.finalEligibleUids.includes(player2Uid));
  assert.ok(room.finalEligibleUids.length >= 1);
  assert.ok(Array.isArray(room.finalThemePool));
  assert.ok(room.finalThemePool.length >= 1);

  while ((room.finalThemePool ?? []).length > 1) {
    await call(hostUid, 'delete_final_theme', { theme: room.finalThemePool[0] }, roomId);
    room = await readRoom();
  }
  assert.equal(room.finalThemePool.length, 1);
  assert.ok((room.finalTheme || '').length > 0);
  assert.ok((room.finalQuestion || '').length > 0);

  await call(hostUid, 'open_final_wagers', {}, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'final_wagering');
  assert.equal(room.engineStage, 'round');

  const finalEligible = [...room.finalEligibleUids];
  assert.ok(finalEligible.length >= 1);
  const ineligiblePlayers = [player1Uid, player2Uid].filter((id) => !finalEligible.includes(id));
  const firstEligible = finalEligible[0];
  const secondEligible = finalEligible.length > 1 ? finalEligible[1] : null;

  await call(firstEligible, 'submit_final_wager', { wager: 300 }, roomId);
  if (secondEligible) {
    await assert.rejects(
      () => call(hostUid, 'open_final_answers', {}, roomId),
      (error) => error && error.code === 'failed-precondition',
    );
    await assert.rejects(
      () => call(secondEligible, 'submit_final_wager', { wager: 0 }, roomId),
      (error) => error && error.code === 'failed-precondition',
    );
    await call(secondEligible, 'submit_final_wager', { wager: 200 }, roomId);
    await assert.rejects(
      () => call(secondEligible, 'submit_final_wager', { wager: 100 }, roomId),
      (error) => error && error.code === 'failed-precondition',
    );
  }
  if (ineligiblePlayers.length > 0) {
    await assert.rejects(
      () => call(ineligiblePlayers[0], 'submit_final_wager', { wager: 100 }, roomId),
      (error) => error && error.code === 'permission-denied',
    );
  }

  await call(hostUid, 'open_final_answers', {}, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'final_answering');
  assert.equal(room.engineStage, 'round');
  assert.ok(Array.isArray(room.finalAnswerOrder));
  assert.equal(room.finalAnswerOrder.length, finalEligible.length);
  assert.equal(typeof room.finalAnswerCurrentUid, 'string');

  await assert.rejects(
    () => call(hostUid, 'reveal_final', {}, roomId),
    (error) => error && error.code === 'failed-precondition',
  );

  const firstFinalUid = room.finalAnswerCurrentUid;
  const secondFinalUid = room.finalAnswerOrder.find((uid) => uid !== firstFinalUid);
  assert.ok(firstFinalUid);
  if (secondFinalUid) {
    await assert.rejects(
      () => call(secondFinalUid, 'submit_final_answer', { answer: 'Out of turn' }, roomId),
      (error) => error && error.code === 'failed-precondition',
    );
    await assert.rejects(
      () => call(hostUid, 'set_final_player_result', { targetUid: secondFinalUid, result: 'wrong' }, roomId),
      (error) => error && error.code === 'failed-precondition',
    );
  }

  await call(
    firstFinalUid,
    'submit_final_answer',
    { answer: 'First final answer' },
    roomId,
  );
  await assert.rejects(
    () => call(firstFinalUid, 'submit_final_answer', { answer: 'Second submit' }, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
  await call(
    hostUid,
    'set_final_player_result',
    { targetUid: firstFinalUid, result: firstFinalUid === player1Uid ? 'correct' : 'wrong' },
    roomId,
  );
  room = await readRoom();
  if (secondFinalUid) {
    assert.equal(room.finalAnswerCurrentUid, secondFinalUid);
    await call(
      secondFinalUid,
      'submit_final_answer',
      { answer: 'Second final answer' },
      roomId,
    );
    await call(
      hostUid,
      'set_final_player_result',
      { targetUid: secondFinalUid, result: secondFinalUid === player1Uid ? 'correct' : 'wrong' },
      roomId,
    );
    room = await readRoom();
    assert.equal(room.finalAnswerCurrentUid, null);
  } else {
    assert.equal(room.finalAnswerCurrentUid, null);
  }

  await call(hostUid, 'reveal_final', {}, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'final_reveal');
  assert.ok((room.finalRevealCurrentUid || '').length > 0);

  for (let i = 0; i < 5; i += 1) {
    if (room.phase === 'game_over') {
      break;
    }
    await call(hostUid, 'reveal_final', {}, roomId);
    room = await readRoom();
  }
  assert.equal(room.phase, 'game_over');
  assert.equal(room.status, 'completed');
  assert.equal(room.engineStage, 'end_game');

  p1 = await readPlayer(player1Uid);
  p2 = await readPlayer(player2Uid);
  for (const uid of finalEligible) {
    const player = uid === player1Uid ? p1 : p2;
    assert.equal(Boolean(player.finalWagerSubmitted), true);
    assert.notEqual(String(player.finalResult), 'pending');
  }
});

test('timer expiration auto-completes final wagering and final answering', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-timer-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostTimer' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1Timer' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2Timer' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'TimerFinal' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);

  await roomRef.collection('players').doc(p1Uid).set(
    { score: 400, finalResult: 'pending', finalWager: 0, finalWagerSubmitted: false },
    { merge: true },
  );
  await roomRef.collection('players').doc(p2Uid).set(
    { score: 200, finalResult: 'pending', finalWager: 0, finalWagerSubmitted: false },
    { merge: true },
  );
  await roomRef.update({
    status: 'final_round',
    phase: 'final_wagering',
    finalEligibleUids: [p1Uid, p2Uid],
    finalTheme: 'Timer final theme',
    finalQuestion: 'Timer final question',
    finalAnswer: 'Timer final answer',
    timerDeadlineAtMs: Date.now() - 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(hostUid, 'handle_timer_expiration', {}, roomId);
  let room = (await roomRef.get()).data();
  assert.equal(room.phase, 'final_answering');
  const p1AfterWager = (await roomRef.collection('players').doc(p1Uid).get()).data();
  const p2AfterWager = (await roomRef.collection('players').doc(p2Uid).get()).data();
  assert.equal(Boolean(p1AfterWager.finalWagerSubmitted), true);
  assert.equal(Boolean(p2AfterWager.finalWagerSubmitted), true);
  assert.equal(Number(p1AfterWager.finalWager), 0);
  assert.equal(Number(p2AfterWager.finalWager), 0);

  await roomRef.collection('players').doc(room.finalAnswerCurrentUid).set(
    { finalResult: 'correct' },
    { merge: true },
  );
  await roomRef.update({
    timerDeadlineAtMs: Date.now() - 1,
    pressBlockedUntilMs: Date.now() - 1,
  });
  await call(hostUid, 'handle_timer_expiration', {}, roomId);

  room = (await roomRef.get()).data();
  assert.equal(room.phase, 'final_reveal');
  const p1AfterAnswer = (await roomRef.collection('players').doc(p1Uid).get()).data();
  const p2AfterAnswer = (await roomRef.collection('players').doc(p2Uid).get()).data();
  const results = [String(p1AfterAnswer.finalResult), String(p2AfterAnswer.finalResult)].sort();
  assert.deepEqual(results, ['correct', 'no_answer']);
});

test('timer expiration auto-advances final reveal to game over', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-reveal-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalReveal' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1FinalReveal' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2FinalReveal' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalRevealAuto' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);

  await roomRef.collection('players').doc(p1Uid).set(
    {
      score: 200,
      finalWager: 100,
      finalWagerSubmitted: true,
      finalResult: 'correct',
      finalRevealed: false,
    },
    { merge: true },
  );
  await roomRef.collection('players').doc(p2Uid).set(
    {
      score: 300,
      finalWager: 200,
      finalWagerSubmitted: true,
      finalResult: 'wrong',
      finalRevealed: false,
    },
    { merge: true },
  );

  await roomRef.update({
    status: 'final_round',
    phase: 'final_reveal',
    finalEligibleUids: [p1Uid, p2Uid],
    finalRevealOrder: [p1Uid, p2Uid],
    finalRevealIndex: 0,
    finalRevealCurrentUid: p1Uid,
    timerDeadlineAtMs: Date.now() - 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(hostUid, 'handle_timer_expiration', {}, roomId);
  let room = (await roomRef.get()).data();
  assert.equal(room.phase, 'final_reveal');
  assert.equal(room.finalRevealCurrentUid, p2Uid);
  assert.ok(Number(room.timerDeadlineAtMs || 0) > Date.now());

  const p1After = (await roomRef.collection('players').doc(p1Uid).get()).data();
  assert.equal(Boolean(p1After.finalRevealed), true);
  assert.equal(Number(p1After.score), 300);

  await roomRef.update({ timerDeadlineAtMs: Date.now() - 1 });
  await call(hostUid, 'handle_timer_expiration', {}, roomId);
  room = (await roomRef.get()).data();
  assert.equal(room.phase, 'game_over');
  assert.equal(room.status, 'completed');

  const p2After = (await roomRef.collection('players').doc(p2Uid).get()).data();
  assert.equal(Boolean(p2After.finalRevealed), true);
  assert.equal(Number(p2After.score), 100);
});

test('timer expiration auto-resolves answer review as wrong answer', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-answer-review-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostAnswerReview' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1AnswerReview' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2AnswerReview' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'AnswerReviewTimeout' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await call(
    hostUid,
    'add_question',
    {
      theme: 'Review',
      text: 'Review timeout',
      answer: 'A',
      cost: 100,
      round: 1,
      type: 'normal',
      mediaType: 'none',
    },
    roomId,
  );

  const qSnap = await roomRef.collection('questions').limit(1).get();
  const questionId = qSnap.docs[0].id;

  await call(hostUid, 'start_game', {}, roomId);
  await call(hostUid, 'pick_question', { questionId }, roomId);
  await call(hostUid, 'open_buzzing', {}, roomId);
  await call(p1Uid, 'buzz', {}, roomId);
  await call(p1Uid, 'submit_answer', {}, roomId);

  let room = (await roomRef.get()).data();
  assert.equal(room.phase, 'answer_review');
  assert.ok(Number(room.timerDeadlineAtMs || 0) > Date.now());

  await roomRef.update({ timerDeadlineAtMs: Date.now() - 1 });
  await call(hostUid, 'handle_timer_expiration', {}, roomId);

  room = (await roomRef.get()).data();
  assert.equal(room.phase, 'answering');
  assert.equal(room.currentAttemptUid, null);
  assert.deepEqual(room.buzzQueue, [p1Uid]);
  assert.ok(Number(room.pressBlockedUntilMs || 0) > Date.now());

  const p1 = (await roomRef.collection('players').doc(p1Uid).get()).data();
  assert.equal(Number(p1.score), -100);
  assert.equal(Number(p1.wrongAnswers), 1);
});

test('timer expiration from question_reveal without active question returns to board_select', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-qreveal-no-active-${Date.now()}`;
  await db.collection('profiles').doc(hostUid).set({ nickname: 'HostQRevealNoActive' });

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'QRevealNoActiveRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await roomRef.update({
    status: 'in_game',
    phase: 'question_reveal',
    activeQuestion: null,
    currentQuestionId: null,
    timerDeadlineAtMs: Date.now() - 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(hostUid, 'handle_timer_expiration', {}, roomId);
  const room = (await roomRef.get()).data() || {};
  assert.ok(
    String(room.phase) === 'board_select' || String(room.phase) === 'final_setup',
  );
  assert.equal(room.activeQuestion, null);
  assert.equal(room.currentQuestionId, null);
});

test('normal question supports multiple players after wrong answer', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-retry-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostRetry' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1Retry' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2Retry' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'RetryFlow' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await call(
    hostUid,
    'add_question',
    {
      theme: 'Retry',
      text: 'Retry question',
      answer: 'A',
      cost: 100,
      round: 1,
      type: 'normal',
      mediaType: 'none',
    },
    roomId,
  );

  const qSnap = await roomRef.collection('questions').limit(1).get();
  const questionId = qSnap.docs[0].id;

  await call(hostUid, 'start_game', {}, roomId);
  await call(hostUid, 'pick_question', { questionId }, roomId);
  await call(hostUid, 'open_buzzing', {}, roomId);

  await call(p1Uid, 'buzz', {}, roomId);
  await call(p1Uid, 'submit_answer', {}, roomId);
  await call(hostUid, 'judge_answer', { correct: false }, roomId);

  let room = (await roomRef.get()).data();
  assert.equal(room.phase, 'answering');
  assert.equal(room.currentAttemptUid, null);
  assert.deepEqual(room.buzzQueue, [p1Uid]);
  assert.ok(Number(room.pressBlockedUntilMs || 0) > Date.now());

  await assert.rejects(
    () => call(p2Uid, 'buzz', {}, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
  await roomRef.update({
    timerDeadlineAtMs: Date.now() - 1,
    pressBlockedUntilMs: Date.now() - 1,
  });
  await call(hostUid, 'handle_timer_expiration', {}, roomId);
  await assert.rejects(
    () => call(p1Uid, 'buzz', {}, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
  await call(p2Uid, 'buzz', {}, roomId);
  await call(p2Uid, 'submit_answer', {}, roomId);
  await call(hostUid, 'judge_answer', { correct: true }, roomId);
  room = (await roomRef.get()).data();
  assert.ok(room.phase === 'board_select' || room.phase === 'final_setup');
  const p1 = (await roomRef.collection('players').doc(p1Uid).get()).data();
  const p2 = (await roomRef.collection('players').doc(p2Uid).get()).data();
  assert.equal(Number(p1.score), -100);
  assert.equal(Number(p2.score), 100);
});

test('wrong answer does not reopen for disconnected remaining players', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-disconnect-reopen-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostDisconnectReopen' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1DisconnectReopen' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2DisconnectReopen' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'DisconnectReopenRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await call(
    hostUid,
    'add_question',
    {
      theme: 'Disconnect',
      text: 'Question',
      answer: 'A',
      cost: 100,
      round: 1,
      type: 'normal',
      mediaType: 'none',
    },
    roomId,
  );
  const questionId = (await roomRef.collection('questions').limit(1).get()).docs[0].id;

  await call(hostUid, 'start_game', {}, roomId);
  await call(hostUid, 'pick_question', { questionId }, roomId);
  await call(hostUid, 'open_buzzing', {}, roomId);
  await call(p1Uid, 'buzz', {}, roomId);
  await roomRef.collection('players').doc(hostUid).set({ connected: false }, { merge: true });
  await roomRef.collection('players').doc(p2Uid).set({ connected: false }, { merge: true });
  await call(p1Uid, 'submit_answer', {}, roomId);
  await call(hostUid, 'judge_answer', { correct: false }, roomId);

  const room = (await roomRef.get()).data() || {};
  assert.ok(
    room.phase === 'board_select' || room.phase === 'final_setup',
    `unexpected phase after wrong answer with disconnected players: ${room.phase}`,
  );
});

test('disconnected current player cannot submit voice answer', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-disconnect-submit-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostDisconnectSubmit' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1DisconnectSubmit' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'DisconnectSubmitRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(
    hostUid,
    'add_question',
    {
      theme: 'Disconnect',
      text: 'Question',
      answer: 'A',
      cost: 100,
      round: 1,
      type: 'normal',
      mediaType: 'none',
    },
    roomId,
  );

  const questionId = (await roomRef.collection('questions').limit(1).get()).docs[0].id;
  await call(hostUid, 'start_game', {}, roomId);
  await call(hostUid, 'pick_question', { questionId }, roomId);
  await call(hostUid, 'open_buzzing', {}, roomId);
  await call(p1Uid, 'buzz', {}, roomId);
  await roomRef.collection('players').doc(p1Uid).set({ connected: false }, { merge: true });

  await assert.rejects(
    () => call(p1Uid, 'submit_answer', {}, roomId),
    (error) => error && error.code === 'permission-denied',
  );
});

test('disconnected final player cannot submit final wager', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-wager-disconnect-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalWagerDisconnect' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1FinalWagerDisconnect' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalWagerDisconnectRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);

  await roomRef.collection('players').doc(p1Uid).set(
    {
      connected: false,
      score: 300,
      finalWagerSubmitted: false,
    },
    { merge: true },
  );
  await roomRef.update({
    status: 'final_round',
    phase: 'final_wagering',
    finalEligibleUids: [p1Uid],
    timerDeadlineAtMs: Date.now() + 60_000,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await assert.rejects(
    () => call(p1Uid, 'submit_final_wager', { wager: 100 }, roomId),
    (error) => error && error.code === 'permission-denied',
  );
});

test('wager amount is clamped to chooser score when score is below 100', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-lowwager-${Date.now()}`;
  await db.collection('profiles').doc(hostUid).set({ nickname: 'HostLowWager' });

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'LowWager' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(
    hostUid,
    'add_question',
    {
      theme: 'LowWager',
      text: 'Auction',
      answer: 'A',
      cost: 300,
      round: 1,
      type: 'wager',
      mediaType: 'none',
    },
    roomId,
  );

  const qSnap = await roomRef.collection('questions').limit(1).get();
  const questionId = qSnap.docs[0].id;

  await call(hostUid, 'start_game', {}, roomId);
  await call(hostUid, 'apply_score', { targetUid: hostUid, delta: 50 }, roomId);
  await call(hostUid, 'pick_question', { questionId }, roomId);
  await call(hostUid, 'set_wager_and_open', { wager: 999 }, roomId);

  const room = (await roomRef.get()).data();
  assert.equal(room.phase, 'answering');
  assert.equal(Number(room.wagerValue), 50);
});

test('stake allows any connected player to set wager for themselves', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-stake-self-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostStakeSelf' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1StakeSelf' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2StakeSelf' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'StakeSelfRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await call(hostUid, 'add_question', {
    theme: 'Stake',
    text: 'Stake question',
    answer: 'A',
    cost: 200,
    round: 1,
    type: 'stake',
    mediaType: 'none',
  }, roomId);

  await roomRef.collection('players').doc(p2Uid).set({ score: 350 }, { merge: true });
  await call(hostUid, 'start_game', {}, roomId);
  await roomRef.update({ chooserUid: p1Uid });
  const qSnap = await roomRef.collection('questions').limit(1).get();
  const qId = qSnap.docs[0].id;
  await call(hostUid, 'pick_question', { questionId: qId }, roomId);

  await call(p2Uid, 'set_wager_and_open', { wager: 300 }, roomId);
  const room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'answering');
  assert.equal(String(room.currentAttemptUid), p2Uid);
  assert.equal(Number(room.wagerValue), 300);
});

test('stake timer expiration picks highest-score connected player', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-stake-timeout-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostStakeTimeout' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1StakeTimeout' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2StakeTimeout' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'StakeTimeoutRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await call(hostUid, 'add_question', {
    theme: 'Stake',
    text: 'Stake timeout',
    answer: 'A',
    cost: 200,
    round: 1,
    type: 'stake',
    mediaType: 'none',
  }, roomId);

  await roomRef.collection('players').doc(p1Uid).set({ score: 150 }, { merge: true });
  await roomRef.collection('players').doc(p2Uid).set({ score: 400 }, { merge: true });
  await call(hostUid, 'start_game', {}, roomId);
  const qSnap = await roomRef.collection('questions').limit(1).get();
  const qId = qSnap.docs[0].id;
  await call(hostUid, 'pick_question', { questionId: qId }, roomId);

  await roomRef.update({
    timerDeadlineAtMs: Date.now() - 1000,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await call(hostUid, 'handle_timer_expiration', {}, roomId);
  const room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'answering');
  assert.equal(String(room.currentAttemptUid), p2Uid);
  assert.equal(Number(room.wagerValue), 400);
});

test('closest_number resolves immediately when all connected answers submitted', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-closest-fast-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostClosestFast' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1ClosestFast' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2ClosestFast' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'ClosestFastRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await call(hostUid, 'add_questions_bulk', {
    questions: [
      {
        theme: 'Closest',
        text: 'Closest first',
        answer: '10',
        cost: 200,
        round: 1,
        type: 'closest_number',
        mediaType: 'none',
      },
      {
        theme: 'Closest',
        text: 'Normal next',
        answer: 'A',
        cost: 100,
        round: 1,
        type: 'normal',
        mediaType: 'none',
      },
    ],
  }, roomId);

  const qSnap = await roomRef.collection('questions').get();
  const closestId = qSnap.docs.find((d) => String(d.data()?.type || '') === 'closest_number').id;
  await call(hostUid, 'start_game', {}, roomId);
  await call(hostUid, 'pick_question', { questionId: closestId }, roomId);

  await call(p1Uid, 'submit_numeric_answer', { value: 10 }, roomId);
  let room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'answering');
  await call(p2Uid, 'submit_numeric_answer', { value: 9 }, roomId);
  room = (await roomRef.get()).data() || {};
  const p1 = (await roomRef.collection('players').doc(p1Uid).get()).data() || {};
  const p2 = (await roomRef.collection('players').doc(p2Uid).get()).data() || {};
  assert.equal(String(room.phase), 'board_select');
  assert.equal(String(room.chooserUid), p1Uid);
  assert.equal(Number(p1.score || 0), 400);
  assert.equal(Number(p1.correctAnswers || 0), 1);
  assert.equal(Number(p2.score || 0), 0);
});

test('pick_question rejects selecting question from another round', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-round-select-guard-${Date.now()}`;
  await db.collection('profiles').doc(hostUid).set({ nickname: 'HostRoundSelectGuard' });

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'RoundSelectGuardRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(
    hostUid,
    'add_questions_bulk',
    {
      questions: [
        {
          theme: 'R1',
          text: 'R1 Q',
          answer: 'A1',
          cost: 100,
          round: 1,
          type: 'normal',
          mediaType: 'none',
        },
        {
          theme: 'R2',
          text: 'R2 Q',
          answer: 'A2',
          cost: 100,
          round: 2,
          type: 'normal',
          mediaType: 'none',
        },
      ],
    },
    roomId,
  );

  const qSnap = await roomRef.collection('questions').get();
  const round2QuestionId = qSnap.docs.find((d) => Number(d.data().round || 1) === 2).id;

  await call(hostUid, 'start_game', {}, roomId);
  await assert.rejects(
    () => call(hostUid, 'pick_question', { questionId: round2QuestionId }, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
});

test('board_select auto-reassigns chooser when current chooser is disconnected', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-chooser-reassign-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostChooserReassign' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1ChooserReassign' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'ChooserReassignRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);

  await call(
    hostUid,
    'add_question',
    {
      theme: 'R1',
      text: 'Q',
      answer: 'A',
      cost: 100,
      round: 1,
      type: 'normal',
      mediaType: 'none',
    },
    roomId,
  );
  await call(hostUid, 'start_game', {}, roomId);
  await roomRef.collection('players').doc(hostUid).set({ connected: false }, { merge: true });
  await roomRef.update({
    chooserUid: hostUid,
    phase: 'board_select',
    status: 'in_game',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(hostUid, 'handle_timer_expiration', {}, roomId);
  const room = (await roomRef.get()).data() || {};
  assert.equal(String(room.chooserUid), p1Uid);
});

test('disconnecting current attempt player auto-resolves attempt without manual timer', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-disconnect-attempt-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostDisconnectAttempt' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1DisconnectAttempt' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2DisconnectAttempt' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'DisconnectAttemptRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await call(
    hostUid,
    'add_question',
    {
      theme: 'R1',
      text: 'Q',
      answer: 'A',
      cost: 100,
      round: 1,
      type: 'normal',
      mediaType: 'none',
    },
    roomId,
  );

  const questionId = (await roomRef.collection('questions').limit(1).get()).docs[0].id;
  await call(hostUid, 'start_game', {}, roomId);
  await call(hostUid, 'pick_question', { questionId }, roomId);
  await call(hostUid, 'open_buzzing', {}, roomId);
  await call(p1Uid, 'buzz', {}, roomId);

  await call(p1Uid, 'mark_disconnected', {}, roomId);

  const room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'answering');
  assert.equal(room.currentAttemptUid, null);
  assert.ok(Array.isArray(room.buzzQueue) && room.buzzQueue.includes(p1Uid));
});

test('kicking chooser during board_select reassigns chooser immediately', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-kick-chooser-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostKickChooser' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1KickChooser' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'KickChooserRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await roomRef.update({
    status: 'in_game',
    phase: 'board_select',
    chooserUid: p1Uid,
    currentRound: 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(hostUid, 'kick_player', { targetUid: p1Uid }, roomId);
  const room = (await roomRef.get()).data() || {};
  assert.equal(String(room.chooserUid), hostUid);
});

test('final_setup auto-resolves deleter tie when one candidate disconnects', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-tie-heal-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalTieHeal' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1FinalTieHeal' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2FinalTieHeal' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalTieHealRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await roomRef.collection('players').doc(p1Uid).set({ score: 100 }, { merge: true });
  await roomRef.collection('players').doc(p2Uid).set({ score: 100 }, { merge: true });
  await roomRef.update({
    status: 'final_round',
    phase: 'final_setup',
    finalThemePool: ['T1', 'T2', 'T3'],
    finalEligibleUids: [p1Uid, p2Uid],
    finalThemeDeleteOrder: [p1Uid, p2Uid],
    finalThemeDeleteCandidates: [p1Uid, p2Uid],
    finalThemeDeleteNeedsSelection: true,
    finalThemeDeleteIndex: -1,
    finalThemeDeleteCurrentUid: null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(p2Uid, 'mark_disconnected', {}, roomId);
  const room = (await roomRef.get()).data() || {};
  assert.deepEqual(room.finalThemeDeleteOrder, [p1Uid]);
  assert.deepEqual(room.finalThemeDeleteCandidates, [p1Uid]);
  assert.equal(Boolean(room.finalThemeDeleteNeedsSelection), false);
  assert.equal(String(room.finalThemeDeleteCurrentUid), p1Uid);
});

test('final_setup switches deleter when current deleter disconnects', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-deleter-switch-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalDeleterSwitch' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1FinalDeleterSwitch' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2FinalDeleterSwitch' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalDeleterSwitchRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await roomRef.collection('players').doc(p1Uid).set({ score: 50 }, { merge: true });
  await roomRef.collection('players').doc(p2Uid).set({ score: 200 }, { merge: true });
  await roomRef.update({
    status: 'final_round',
    phase: 'final_setup',
    finalThemePool: ['A', 'B'],
    finalEligibleUids: [p1Uid, p2Uid],
    finalThemeDeleteOrder: [p1Uid, p2Uid],
    finalThemeDeleteCandidates: [p1Uid],
    finalThemeDeleteNeedsSelection: false,
    finalThemeDeleteIndex: 0,
    finalThemeDeleteCurrentUid: p1Uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(p1Uid, 'mark_disconnected', {}, roomId);
  const room = (await roomRef.get()).data() || {};
  assert.deepEqual(room.finalThemeDeleteOrder, [p2Uid]);
  assert.equal(Boolean(room.finalThemeDeleteNeedsSelection), false);
  assert.equal(String(room.finalThemeDeleteCurrentUid), p2Uid);
});

test('set_player_role to spectator during final_wagering auto-submits wager and opens answering', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-wager-role-heal-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalWagerRoleHeal' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1FinalWagerRoleHeal' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2FinalWagerRoleHeal' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalWagerRoleHealRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await roomRef.collection('players').doc(p1Uid).set(
    { score: 300, finalWagerSubmitted: true, finalWager: 100 },
    { merge: true },
  );
  await roomRef.collection('players').doc(p2Uid).set(
    { score: 200, finalWagerSubmitted: false, finalWager: 0 },
    { merge: true },
  );
  await roomRef.update({
    status: 'final_round',
    phase: 'final_wagering',
    finalEligibleUids: [p1Uid, p2Uid],
    timerDeadlineAtMs: Date.now() + 60_000,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(hostUid, 'set_player_role', { targetUid: p2Uid, role: 'spectator' }, roomId);
  const room = (await roomRef.get()).data() || {};
  const p2 = (await roomRef.collection('players').doc(p2Uid).get()).data() || {};
  assert.equal(String(room.phase), 'final_answering');
  assert.equal(Boolean(p2.finalWagerSubmitted), true);
  assert.equal(Number(p2.finalWager || 0), 0);
});

test('set_player_role to spectator for current final answerer advances to next pending', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-answer-role-heal-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalAnswerRoleHeal' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1FinalAnswerRoleHeal' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2FinalAnswerRoleHeal' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalAnswerRoleHealRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await roomRef.collection('players').doc(p1Uid).set(
    { finalResult: 'pending', finalAnswerSubmitted: false },
    { merge: true },
  );
  await roomRef.collection('players').doc(p2Uid).set(
    { finalResult: 'pending', finalAnswerSubmitted: false },
    { merge: true },
  );
  await roomRef.update({
    status: 'final_round',
    phase: 'final_answering',
    finalEligibleUids: [p1Uid, p2Uid],
    finalAnswerOrder: [p1Uid, p2Uid],
    finalAnswerIndex: 0,
    finalAnswerCurrentUid: p1Uid,
    timerDeadlineAtMs: Date.now() + 60_000,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(hostUid, 'set_player_role', { targetUid: p1Uid, role: 'spectator' }, roomId);
  const room = (await roomRef.get()).data() || {};
  const p1 = (await roomRef.collection('players').doc(p1Uid).get()).data() || {};
  assert.equal(String(room.phase), 'final_answering');
  assert.equal(String(room.finalAnswerCurrentUid), p2Uid);
  assert.equal(Number(room.finalAnswerIndex), 1);
  assert.equal(String(p1.finalResult), 'no_answer');
});

test('set_player_role to spectator for last pending final answerer auto-opens reveal', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-answer-last-role-heal-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalAnswerLastRoleHeal' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1FinalAnswerLastRoleHeal' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalAnswerLastRoleHealRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await roomRef.collection('players').doc(p1Uid).set(
    { finalResult: 'pending', finalAnswerSubmitted: false, finalWager: 100, score: 400 },
    { merge: true },
  );
  await roomRef.update({
    status: 'final_round',
    phase: 'final_answering',
    finalEligibleUids: [p1Uid],
    finalAnswerOrder: [p1Uid],
    finalAnswerIndex: 0,
    finalAnswerCurrentUid: p1Uid,
    timerDeadlineAtMs: Date.now() + 60_000,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(hostUid, 'set_player_role', { targetUid: p1Uid, role: 'spectator' }, roomId);
  const room = (await roomRef.get()).data() || {};
  const p1 = (await roomRef.collection('players').doc(p1Uid).get()).data() || {};
  assert.equal(String(p1.finalResult), 'no_answer');
  assert.ok(String(room.phase) === 'final_reveal' || String(room.phase) === 'game_over');
});

test('single eligible final player flow works with extra spectators', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-single-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const spectatorUid = `${hostUid}-spec`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalSingle' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1FinalSingle' }),
    db.collection('profiles').doc(spectatorUid).set({ nickname: 'SpecFinalSingle' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalSingleEligible' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(spectatorUid, 'join_room', { role: 'spectator' }, roomId);
  await roomRef.collection('players').doc(p1Uid).set(
    {
      connected: true,
      role: 'player',
      score: 500,
      finalWager: 0,
      finalWagerSubmitted: false,
      finalAnswerSubmitted: false,
      finalResult: 'pending',
      finalRevealed: false,
    },
    { merge: true },
  );
  await roomRef.collection('players').doc(spectatorUid).set(
    { connected: true, role: 'spectator', score: 900 },
    { merge: true },
  );
  await roomRef.update({
    status: 'final_round',
    phase: 'final_setup',
    finalThemePool: ['SingleTheme'],
    finalTheme: 'SingleTheme',
    finalQuestion: 'Single final question',
    finalAnswer: 'Single final answer',
    finalEligibleUids: [p1Uid],
    timerDeadlineAtMs: null,
    timerRemainingMs: null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(hostUid, 'open_final_wagers', {}, roomId);
  let room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'final_wagering');
  assert.deepEqual(room.finalEligibleUids, [p1Uid]);

  await assert.rejects(
    () => call(hostUid, 'open_final_answers', {}, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
  await assert.rejects(
    () => call(spectatorUid, 'submit_final_wager', { wager: 100 }, roomId),
    (error) => error && error.code === 'permission-denied',
  );

  await call(p1Uid, 'submit_final_wager', { wager: 300 }, roomId);
  await call(hostUid, 'open_final_answers', {}, roomId);
  room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'final_answering');
  assert.deepEqual(room.finalAnswerOrder, [p1Uid]);
  assert.equal(String(room.finalAnswerCurrentUid), p1Uid);

  await assert.rejects(
    () => call(spectatorUid, 'submit_final_answer', { answer: 'spec' }, roomId),
    (error) => error && error.code === 'permission-denied',
  );
  await call(p1Uid, 'submit_final_answer', { answer: 'my final' }, roomId);
  await call(hostUid, 'set_final_player_result', { targetUid: p1Uid, result: 'correct' }, roomId);
  room = (await roomRef.get()).data() || {};
  assert.equal(room.finalAnswerCurrentUid, null);

  await call(hostUid, 'reveal_final', {}, roomId);
  room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'final_reveal');
  assert.equal(String(room.finalRevealCurrentUid), p1Uid);

  await call(hostUid, 'reveal_final', {}, roomId);
  room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'game_over');
  assert.equal(String(room.status), 'completed');
});

test('final_reveal auto-heal normalizes broken reveal cursor after roster change', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-reveal-heal-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalRevealHeal' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1FinalRevealHeal' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2FinalRevealHeal' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalRevealHealRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);

  await roomRef.collection('players').doc(p1Uid).set(
    { finalRevealed: false, finalResult: 'correct', finalWager: 100, score: 500 },
    { merge: true },
  );
  await roomRef.collection('players').doc(p2Uid).set(
    { finalRevealed: true, finalResult: 'wrong', finalWager: 200, score: 600 },
    { merge: true },
  );
  await roomRef.update({
    status: 'final_round',
    phase: 'final_reveal',
    finalEligibleUids: [p1Uid, p2Uid, 'ghost'],
    finalRevealOrder: ['ghost', p2Uid],
    finalRevealIndex: 99,
    finalRevealCurrentUid: 'ghost',
    timerDeadlineAtMs: null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(p1Uid, 'mark_disconnected', {}, roomId);
  const room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'final_reveal');
  assert.deepEqual(room.finalRevealOrder, [p2Uid, p1Uid]);
  assert.equal(String(room.finalRevealCurrentUid), p1Uid);
  assert.equal(Number(room.finalRevealIndex), 1);
  assert.ok(Number(room.timerDeadlineAtMs || 0) > Date.now());
});

test('final_reveal auto-heal ends game when everyone already revealed', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-reveal-end-heal-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalRevealEndHeal' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1FinalRevealEndHeal' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalRevealEndHealRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await roomRef.collection('players').doc(p1Uid).set(
    { finalRevealed: true, finalResult: 'correct', finalWager: 50, score: 100 },
    { merge: true },
  );
  await roomRef.update({
    status: 'final_round',
    phase: 'final_reveal',
    finalEligibleUids: [p1Uid],
    finalRevealOrder: [p1Uid],
    finalRevealIndex: 0,
    finalRevealCurrentUid: p1Uid,
    timerDeadlineAtMs: Date.now() + 60_000,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(p1Uid, 'mark_disconnected', {}, roomId);
  const room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'game_over');
  assert.equal(String(room.status), 'completed');
});

test('timer expiration auto-resolves cat and wager phases', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-autoresolve-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostAutoResolve' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1AutoResolve' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2AutoResolve' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'AutoResolve' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await roomRef.collection('questions').add({
    theme: 'Auto',
    text: 'Cat q',
    answer: 'A',
    cost: 200,
    round: 1,
    type: 'cat_in_bag',
    used: false,
    createdBy: hostUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await roomRef.collection('questions').add({
    theme: 'Auto',
    text: 'Wager q',
    answer: 'B',
    cost: 300,
    round: 1,
    type: 'wager',
    used: false,
    createdBy: hostUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const qSnap = await roomRef.collection('questions').get();
  const catId = qSnap.docs.find((d) => d.data().type === 'cat_in_bag').id;
  const wagerId = qSnap.docs.find((d) => d.data().type === 'wager').id;

  await call(hostUid, 'start_game', {}, roomId);
  await call(hostUid, 'pick_question', { questionId: catId }, roomId);
  await roomRef.update({ timerDeadlineAtMs: Date.now() - 1 });
  await call(hostUid, 'handle_timer_expiration', {}, roomId);

  let room = (await roomRef.get()).data();
  assert.equal(room.phase, 'answering');
  assert.ok(String(room.currentAttemptUid || '').length > 0);
  assert.ok(String(room.targetedUid || '').length > 0);

  await call(room.currentAttemptUid, 'submit_answer', {}, roomId);
  await call(hostUid, 'judge_answer', { correct: false }, roomId);
  room = (await roomRef.get()).data();
  assert.equal(room.phase, 'board_select');

  await call(hostUid, 'pick_question', { questionId: wagerId }, roomId);
  await roomRef.update({ timerDeadlineAtMs: Date.now() - 1 });
  await call(hostUid, 'handle_timer_expiration', {}, roomId);
  room = (await roomRef.get()).data();
  assert.equal(room.phase, 'answering');
  assert.ok(String(room.currentAttemptUid || '').length > 0);
  assert.ok(Number(room.wagerValue) >= 0);
});

test('timer expiration targets only connected players in cat and wager phases', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-connected-timeout-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostConnectedTimeout' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1ConnectedTimeout' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2ConnectedTimeout' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'ConnectedTimeoutRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await roomRef.collection('questions').add({
    theme: 'Conn',
    text: 'Cat',
    answer: 'A',
    cost: 200,
    round: 1,
    type: 'cat_in_bag',
    used: false,
    createdBy: hostUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await roomRef.collection('questions').add({
    theme: 'Conn',
    text: 'Wager',
    answer: 'B',
    cost: 300,
    round: 1,
    type: 'wager',
    used: false,
    createdBy: hostUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const qSnap = await roomRef.collection('questions').get();
  const catId = qSnap.docs.find((d) => d.data().type === 'cat_in_bag').id;
  const wagerId = qSnap.docs.find((d) => d.data().type === 'wager').id;

  await call(hostUid, 'start_game', {}, roomId);
  await roomRef.collection('players').doc(hostUid).set({ connected: false }, { merge: true });
  await roomRef.collection('players').doc(p1Uid).set({ connected: false }, { merge: true });
  await roomRef.collection('players').doc(p2Uid).set({ connected: true }, { merge: true });

  await call(hostUid, 'pick_question', { questionId: catId }, roomId);
  await roomRef.update({ timerDeadlineAtMs: Date.now() - 1 });
  await call(hostUid, 'handle_timer_expiration', {}, roomId);
  let room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'answering');
  assert.equal(String(room.currentAttemptUid), p2Uid);
  assert.equal(String(room.targetedUid), p2Uid);

  await call(p2Uid, 'submit_answer', {}, roomId);
  await call(hostUid, 'judge_answer', { correct: false }, roomId);

  await call(hostUid, 'pick_question', { questionId: wagerId }, roomId);
  await roomRef.update({ timerDeadlineAtMs: Date.now() - 1 });
  await call(hostUid, 'handle_timer_expiration', {}, roomId);
  room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'answering');
  assert.equal(String(room.currentAttemptUid), p2Uid);
});

test('final commands are rejected in wrong phases', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-phase-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostPhase' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1Phase' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'PhaseGuard' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);

  await assert.rejects(
    () => call(hostUid, 'open_final_wagers', {}, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
  await assert.rejects(
    () => call(p1Uid, 'submit_final_answer', { answer: 'A' }, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
  await assert.rejects(
    () => call(hostUid, 'set_final_question', { theme: 'A', question: 'Q', answer: 'A' }, roomId),
    (error) => error && error.code === 'failed-precondition',
  );

  await roomRef.update({
    status: 'final_round',
    phase: 'final_setup',
    finalThemePool: ['A'],
    finalTheme: 'A',
    finalQuestion: 'Q',
    finalAnswer: 'A',
    finalEligibleUids: [p1Uid],
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await assert.rejects(
    () => call(hostUid, 'open_final_answers', {}, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
  await assert.rejects(
    () => call(hostUid, 'set_final_player_result', { targetUid: p1Uid, result: 'correct' }, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
  await assert.rejects(
    () => call(hostUid, 'reveal_final', {}, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
});

test('set_final_question stores final answer text', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-question-${Date.now()}`;
  await db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalQuestion' });

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalQuestionRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await roomRef.update({
    status: 'final_round',
    phase: 'final_setup',
    finalThemePool: ['Theme'],
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(
    hostUid,
    'set_final_question',
    { theme: 'Theme', question: 'Final Q', answer: 'Final A' },
    roomId,
  );

  const room = (await roomRef.get()).data() || {};
  assert.equal(String(room.finalTheme), 'Theme');
  assert.equal(String(room.finalQuestion), 'Final Q');
  assert.equal(String(room.finalAnswer), 'Final A');
});

test('set_final_question validates required fields', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-question-validate-${Date.now()}`;
  await db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalQuestionValidate' });

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalQuestionValidateRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await roomRef.update({
    status: 'final_round',
    phase: 'final_setup',
    finalThemePool: ['Theme'],
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await assert.rejects(
    () => call(
      hostUid,
      'set_final_question',
      { theme: 'Theme', question: 'Final Q', answer: '' },
      roomId,
    ),
    (error) => error && error.code === 'invalid-argument',
  );
});

test('auto-advance does not wrap to lower rounds and starts final', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-round-advance-${Date.now()}`;
  await db.collection('profiles').doc(hostUid).set({ nickname: 'HostRoundAdvance' });

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'RoundAdvanceRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await roomRef.collection('questions').add({
    theme: 'OnlyRound1',
    text: 'Q1',
    answer: 'A1',
    cost: 100,
    round: 1,
    type: 'normal',
    used: false,
    createdBy: hostUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await roomRef.update({
    status: 'in_game',
    phase: 'board_select',
    currentRound: 2,
    timerDeadlineAtMs: Date.now() - 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(hostUid, 'handle_timer_expiration', {}, roomId);

  const room = (await roomRef.get()).data() || {};
  assert.equal(String(room.status), 'final_round');
  assert.equal(String(room.phase), 'final_setup');
  assert.notEqual(Number(room.currentRound || 0), 1);
});

test('reveal_final is idempotent for already revealed current player', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-idempotent-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalIdempotent' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1FinalIdempotent' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2FinalIdempotent' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalIdempotentRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);

  await roomRef.collection('players').doc(p1Uid).set(
    {
      score: 500,
      finalWager: 200,
      finalWagerSubmitted: true,
      finalResult: 'correct',
      finalRevealed: true,
    },
    { merge: true },
  );
  await roomRef.collection('players').doc(p2Uid).set(
    {
      score: 300,
      finalWager: 100,
      finalWagerSubmitted: true,
      finalResult: 'wrong',
      finalRevealed: false,
    },
    { merge: true },
  );
  await roomRef.update({
    status: 'final_round',
    phase: 'final_reveal',
    finalEligibleUids: [p1Uid, p2Uid],
    finalRevealOrder: [p1Uid, p2Uid],
    finalRevealIndex: 0,
    finalRevealCurrentUid: p1Uid,
    timerDeadlineAtMs: Date.now() + 60_000,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await call(hostUid, 'reveal_final', {}, roomId);

  const roomAfter = (await roomRef.get()).data() || {};
  const p1After = (await roomRef.collection('players').doc(p1Uid).get()).data() || {};
  assert.equal(Number(p1After.score), 500);
  assert.equal(String(roomAfter.finalRevealCurrentUid), p2Uid);
  assert.equal(Number(roomAfter.finalRevealIndex), 1);
});

test('gameplay commands are rejected while room is paused', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-paused-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostPaused' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1Paused' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'PausedRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(
    hostUid,
    'add_question',
    {
      theme: 'Pause',
      text: 'Pause question',
      answer: 'A',
      cost: 100,
      round: 1,
      type: 'normal',
      mediaType: 'none',
    },
    roomId,
  );

  const qSnap = await roomRef.collection('questions').limit(1).get();
  const questionId = qSnap.docs[0].id;

  await call(hostUid, 'start_game', {}, roomId);
  await call(hostUid, 'pick_question', { questionId }, roomId);
  await call(hostUid, 'open_buzzing', {}, roomId);
  await call(p1Uid, 'buzz', {}, roomId);
  await call(hostUid, 'pause_game', {}, roomId);

  await assert.rejects(
    () => call(p1Uid, 'submit_answer', {}, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
  await assert.rejects(
    () => call(hostUid, 'judge_answer', { correct: true }, roomId),
    (error) => error && error.code === 'failed-precondition',
  );

  await roomRef.update({
    phase: 'final_setup',
    status: 'paused',
    finalThemePool: ['A'],
    finalTheme: 'A',
    finalQuestion: 'Q',
    finalAnswer: 'A',
    finalEligibleUids: [p1Uid],
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await assert.rejects(
    () => call(hostUid, 'open_final_wagers', {}, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
});

test('disconnected non-host player cannot pause game', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-pause-disconnect-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostPauseDisconnect' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1PauseDisconnect' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'PauseDisconnectRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await roomRef.collection('players').doc(p1Uid).set({ connected: false }, { merge: true });

  await assert.rejects(
    () => call(p1Uid, 'pause_game', {}, roomId),
    (error) => error && error.code === 'permission-denied',
  );
});

test('disconnected chooser cannot pick question', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-pick-disconnect-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostPickDisconnect' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1PickDisconnect' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'PickDisconnectRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(
    hostUid,
    'add_question',
    {
      theme: 'Pick',
      text: 'Pick q',
      answer: 'A',
      cost: 100,
      round: 1,
      type: 'normal',
      mediaType: 'none',
    },
    roomId,
  );
  const qSnap = await roomRef.collection('questions').limit(1).get();
  const questionId = qSnap.docs[0].id;
  await call(hostUid, 'start_game', {}, roomId);
  await roomRef.update({ chooserUid: p1Uid });
  await roomRef.collection('players').doc(p1Uid).set({ connected: false }, { merge: true });

  await assert.rejects(
    () => call(p1Uid, 'pick_question', { questionId }, roomId),
    (error) => error && error.code === 'permission-denied',
  );
});

test('disconnected chooser cannot select cat target', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-cat-disconnect-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostCatDisconnect' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1CatDisconnect' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2CatDisconnect' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'CatDisconnectRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await call(
    hostUid,
    'add_question',
    {
      theme: 'Cat',
      text: 'Cat q',
      answer: 'A',
      cost: 200,
      round: 1,
      type: 'cat_in_bag',
      mediaType: 'none',
    },
    roomId,
  );
  const qSnap = await roomRef.collection('questions').limit(1).get();
  const questionId = qSnap.docs[0].id;

  await call(hostUid, 'start_game', {}, roomId);
  await roomRef.update({ chooserUid: p1Uid });
  await call(hostUid, 'pick_question', { questionId }, roomId);
  await roomRef.collection('players').doc(p1Uid).set({ connected: false }, { merge: true });

  await assert.rejects(
    () => call(p1Uid, 'select_cat_target', { targetUid: p2Uid }, roomId),
    (error) => error && error.code === 'permission-denied',
  );
});

test('disconnected final deleter cannot delete theme', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-final-deleter-disconnect-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostFinalDeleterDisconnect' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1FinalDeleterDisconnect' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'FinalDeleterDisconnectRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await roomRef.update({
    status: 'final_round',
    phase: 'final_setup',
    finalThemePool: ['A', 'B'],
    finalThemeDeleteOrder: [p1Uid],
    finalThemeDeleteIndex: 0,
    finalThemeDeleteCurrentUid: p1Uid,
    finalThemeDeleteNeedsSelection: false,
    finalEligibleUids: [p1Uid],
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await roomRef.collection('players').doc(p1Uid).set({ connected: false }, { merge: true });

  await assert.rejects(
    () => call(p1Uid, 'delete_final_theme', { theme: 'A' }, roomId),
    (error) => error && error.code === 'permission-denied',
  );
});

test('auto-heal forces question_reveal timeout when no connected voice players', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-qreveal-heal-${Date.now()}`;
  await db.collection('profiles').doc(hostUid).set({ nickname: 'HostQRevealHeal' });

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'QRevealHealRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await roomRef.update({
    status: 'in_game',
    phase: 'question_reveal',
    activeQuestion: { id: 'q1', type: 'normal', cost: 100 },
    timerDeadlineAtMs: Date.now() + 60_000,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await roomRef.collection('players').doc(hostUid).set(
    { connected: false, role: 'host' },
    { merge: true },
  );

  await call(hostUid, 'mark_disconnected', {}, roomId);
  const room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'answering');
  assert.ok(Number(room.timerDeadlineAtMs || 0) <= Date.now() + 30_000);
});

test('auto-heal forces answering timeout when no connected voice players and no current attempt', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-answering-heal-${Date.now()}`;
  await db.collection('profiles').doc(hostUid).set({ nickname: 'HostAnsweringHeal' });

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'AnsweringHealRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await roomRef.update({
    status: 'in_game',
    phase: 'answering',
    activeQuestion: { id: 'q1', type: 'normal', cost: 100 },
    currentAttemptUid: null,
    timerDeadlineAtMs: Date.now() + 60_000,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await roomRef.collection('players').doc(hostUid).set(
    { connected: false, role: 'host' },
    { merge: true },
  );

  await call(hostUid, 'mark_disconnected', {}, roomId);
  const room = (await roomRef.get()).data() || {};
  assert.ok(
    String(room.phase) === 'board_select' || String(room.phase) === 'final_setup',
  );
});

test('exhausting round 1 auto-advances to round 2 when questions remain', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-round-auto-advance-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostRoundAutoAdvance' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1RoundAutoAdvance' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'RoundAutoAdvanceRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);

  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(hostUid, 'add_questions_bulk', {
    questions: [
      {
        theme: 'R1',
        text: 'R1-Q1',
        answer: 'A1',
        cost: 100,
        round: 1,
        type: 'normal',
        mediaType: 'none',
      },
      {
        theme: 'R2',
        text: 'R2-Q1',
        answer: 'A2',
        cost: 200,
        round: 2,
        type: 'normal',
        mediaType: 'none',
      },
    ],
  }, roomId);

  const all = await roomRef.collection('questions').get();
  const r1Id = all.docs.find((d) => Number(d.data().round || 1) === 1).id;

  await call(hostUid, 'start_game', {}, roomId);
  await call(hostUid, 'pick_question', { questionId: r1Id }, roomId);
  await call(hostUid, 'open_buzzing', {}, roomId);
  await call(p1Uid, 'buzz', {}, roomId);
  await call(p1Uid, 'submit_answer', {}, roomId);
  await call(hostUid, 'judge_answer', { correct: true }, roomId);

  const room = (await roomRef.get()).data() || {};
  assert.equal(String(room.status), 'in_game');
  assert.ok(
    String(room.phase) === 'board_select' || String(room.phase) === 'final_setup',
  );
  assert.equal(Number(room.currentRound || 0), 2);
});

test('role change to spectator during answer_review auto-resolves current attempt', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-answer-review-role-heal-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostAnswerReviewRoleHeal' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1AnswerReviewRoleHeal' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2AnswerReviewRoleHeal' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'AnswerReviewRoleHealRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);
  await call(hostUid, 'add_question', {
    theme: 'Review',
    text: 'Review role heal',
    answer: 'A',
    cost: 100,
    round: 1,
    type: 'normal',
    mediaType: 'none',
  }, roomId);

  const qSnap = await roomRef.collection('questions').limit(1).get();
  const questionId = qSnap.docs[0].id;

  await call(hostUid, 'start_game', {}, roomId);
  await call(hostUid, 'pick_question', { questionId }, roomId);
  await call(hostUid, 'open_buzzing', {}, roomId);
  await call(p1Uid, 'buzz', {}, roomId);
  await call(p1Uid, 'submit_answer', {}, roomId);

  let room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'answer_review');
  await call(hostUid, 'set_player_role', { targetUid: p1Uid, role: 'spectator' }, roomId);

  room = (await roomRef.get()).data() || {};
  assert.ok(String(room.phase) === 'answering' || String(room.phase) === 'board_select');
  assert.equal(String(room.currentAttemptUid || ''), '');
});

test('long-run flow with all question/media types across two rounds and full final negative checks', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-longrun-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostLongRun' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1LongRun' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2LongRun' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const create = await call(hostUid, 'create_room', { roomName: 'LongRunRoom' });
  const roomId = create.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', { role: 'player' }, roomId);
  await call(p2Uid, 'join_room', { role: 'player' }, roomId);

  await call(hostUid, 'add_questions_bulk', {
    questions: [
      { theme: 'R1', text: 'R1 normal image', answer: 'A1', cost: 100, round: 1, type: 'normal', mediaType: 'image', mediaUrl: 'https://cdn/r1n.png' },
      { theme: 'R1', text: 'R1 cat audio', answer: 'A2', cost: 200, round: 1, type: 'cat_in_bag', mediaType: 'audio', mediaUrl: 'https://cdn/r1c.mp3' },
      { theme: 'R1', text: 'R1 wager video', answer: 'A3', cost: 300, round: 1, type: 'wager', mediaType: 'video', mediaUrl: 'https://cdn/r1w.mp4' },
      { theme: 'R1', text: 'R1 closest none', answer: '10', cost: 400, round: 1, type: 'closest_number', mediaType: 'none', mediaUrl: '' },
      { theme: 'R2', text: 'R2 normal none', answer: 'B1', cost: 100, round: 2, type: 'normal', mediaType: 'none', mediaUrl: '' },
      { theme: 'R2', text: 'R2 cat image', answer: 'B2', cost: 200, round: 2, type: 'cat_in_bag', mediaType: 'image', mediaUrl: 'https://cdn/r2c.png' },
      { theme: 'R2', text: 'R2 wager audio', answer: 'B3', cost: 300, round: 2, type: 'wager', mediaType: 'audio', mediaUrl: 'https://cdn/r2w.mp3' },
      { theme: 'R2', text: 'R2 closest video', answer: '20', cost: 400, round: 2, type: 'closest_number', mediaType: 'video', mediaUrl: 'https://cdn/r2n.mp4' },
    ],
  }, roomId);

  const qSnap = await roomRef.collection('questions').get();
  const questions = qSnap.docs.map((d) => ({ id: d.id, ...(d.data() || {}) }));
  const order = [
    'R1 normal image',
    'R1 cat audio',
    'R1 wager video',
    'R1 closest none',
    'R2 normal none',
    'R2 cat image',
    'R2 wager audio',
    'R2 closest video',
  ];
  const byText = new Map(questions.map((q) => [String(q.text || ''), q]));

  await call(hostUid, 'start_game', {}, roomId);

  for (const text of order) {
    const q = byText.get(text);
    assert.ok(q, `missing question: ${text}`);
    await call(hostUid, 'pick_question', { questionId: q.id }, roomId);

    if (q.type === 'normal') {
      await call(hostUid, 'open_buzzing', {}, roomId);
      await call(p1Uid, 'buzz', {}, roomId);
      await call(p1Uid, 'submit_answer', {}, roomId);
      await call(hostUid, 'judge_answer', { correct: true }, roomId);
      continue;
    }

    if (q.type === 'cat_in_bag') {
      await call(hostUid, 'select_cat_target', { targetUid: p2Uid }, roomId);
      await call(p2Uid, 'submit_answer', {}, roomId);
      await call(hostUid, 'judge_answer', { correct: true }, roomId);
      continue;
    }

    if (q.type === 'wager') {
      await call(hostUid, 'set_wager_and_open', { wager: 100 }, roomId);
      await call(p2Uid, 'submit_answer', {}, roomId);
      await call(hostUid, 'judge_answer', { correct: true }, roomId);
      continue;
    }

    if (q.type === 'closest_number') {
      await call(p1Uid, 'submit_numeric_answer', { value: Number(q.answer || 0) }, roomId);
      await call(p2Uid, 'submit_numeric_answer', { value: Number(q.answer || 0) + 1 }, roomId);
      await roomRef.update({ timerDeadlineAtMs: Date.now() - 1 });
      await call(hostUid, 'handle_timer_expiration', {}, roomId);
      continue;
    }
  }

  let room = (await roomRef.get()).data() || {};
  assert.equal(String(room.status), 'final_round');
  assert.equal(String(room.phase), 'final_setup');

  await call(hostUid, 'set_final_question', {
    theme: 'Long Final',
    question: 'Long final?',
    answer: 'Final',
  }, roomId);
  await call(hostUid, 'open_final_wagers', {}, roomId);

  await assert.rejects(
    () => call(hostUid, 'open_final_answers', {}, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
  await call(p1Uid, 'submit_final_wager', { wager: 100 }, roomId);
  await call(p2Uid, 'submit_final_wager', { wager: 100 }, roomId);
  await call(hostUid, 'open_final_answers', {}, roomId);

  await assert.rejects(
    () => call(hostUid, 'reveal_final', {}, roomId),
    (error) => error && error.code === 'failed-precondition',
  );

  room = (await roomRef.get()).data() || {};
  const answerOrder = Array.isArray(room.finalAnswerOrder) ? room.finalAnswerOrder : [];
  for (const uid of answerOrder) {
    await call(uid, 'submit_final_answer', { answer: `ans-${uid}` }, roomId);
    await call(hostUid, 'set_final_player_result', { targetUid: uid, result: 'correct' }, roomId);
  }

  while (true) {
    room = (await roomRef.get()).data() || {};
    if (String(room.phase) === 'game_over') {
      break;
    }
    await call(hostUid, 'reveal_final', {}, roomId);
  }

  room = (await roomRef.get()).data() || {};
  assert.equal(String(room.status), 'completed');
  assert.equal(String(room.phase), 'game_over');
});

test('secret_no_question auto-resolves immediately with chooser score gain', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-secret-noq-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostSecretNoQ' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1SecretNoQ' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const created = await call(hostUid, 'create_room', { roomName: 'SecretNoQuestion' });
  const roomId = created.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', {}, roomId);

  await call(hostUid, 'add_question', {
    theme: 'Secret',
    text: 'Auto reward',
    answer: 'ignored',
    cost: 500,
    round: 1,
    type: 'secret_no_question',
    mediaType: 'none',
  }, roomId);
  await call(hostUid, 'start_game', {}, roomId);

  const qSnap = await roomRef.collection('questions').limit(1).get();
  const qId = qSnap.docs[0].id;
  await call(hostUid, 'pick_question', { questionId: qId }, roomId);

  const room = (await roomRef.get()).data() || {};
  assert.ok(
    String(room.phase) === 'board_select' || String(room.phase) === 'final_setup',
  );
  assert.equal(String(room.chooserUid), hostUid);

  const hostPlayer = (await roomRef.collection('players').doc(hostUid).get()).data() || {};
  assert.equal(Number(hostPlayer.score || 0), 500);
});

test('no_risk wrong answer does not reduce score', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-no-risk-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostNoRisk' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1NoRisk' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const created = await call(hostUid, 'create_room', { roomName: 'NoRiskRoom' });
  const roomId = created.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', {}, roomId);

  await roomRef.collection('players').doc(p1Uid).set({ score: 700 }, { merge: true });
  await call(hostUid, 'add_question', {
    theme: 'NoRisk',
    text: 'No penalty question',
    answer: 'A',
    cost: 400,
    round: 1,
    type: 'no_risk',
    mediaType: 'none',
  }, roomId);
  await call(hostUid, 'start_game', {}, roomId);

  const qSnap = await roomRef.collection('questions').limit(1).get();
  const qId = qSnap.docs[0].id;
  await call(hostUid, 'pick_question', { questionId: qId }, roomId);
  await call(hostUid, 'open_buzzing', {}, roomId);
  await call(p1Uid, 'buzz', {}, roomId);
  await call(p1Uid, 'submit_answer', {}, roomId);
  await call(hostUid, 'judge_answer', { correct: false }, roomId);

  const p1 = (await roomRef.collection('players').doc(p1Uid).get()).data() || {};
  assert.equal(Number(p1.score || 0), 700);
  assert.equal(Number(p1.wrongAnswers || 0), 1);
});

test('for_yourself question auto-targets chooser without open_buzzing step', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-for-yourself-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostForYourself' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1ForYourself' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const created = await call(hostUid, 'create_room', { roomName: 'ForYourselfRoom' });
  const roomId = created.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', {}, roomId);
  await roomRef.update({ chooserUid: p1Uid });
  await call(hostUid, 'add_question', {
    theme: 'ForYourself',
    text: 'Only chooser answers',
    answer: 'A',
    cost: 200,
    round: 1,
    type: 'for_yourself',
    mediaType: 'none',
  }, roomId);
  await call(hostUid, 'start_game', {}, roomId);
  await roomRef.update({ chooserUid: p1Uid });

  const qSnap = await roomRef.collection('questions').limit(1).get();
  const qId = qSnap.docs[0].id;
  await call(p1Uid, 'pick_question', { questionId: qId }, roomId);

  const room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'answering');
  assert.equal(String(room.currentAttemptUid), p1Uid);
  assert.equal(String(room.targetedUid), p1Uid);

  await assert.rejects(
    () => call(hostUid, 'buzz', {}, roomId),
    (error) => error && error.code === 'failed-precondition',
  );
});

test('appeal accepted turns wrong host verdict into correct result', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-appeal-accept-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostAppealAccept' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1AppealAccept' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2AppealAccept' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const created = await call(hostUid, 'create_room', { roomName: 'AppealAcceptRoom' });
  const roomId = created.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', {}, roomId);
  await call(p2Uid, 'join_room', {}, roomId);
  await call(hostUid, 'update_room_rules', { useAppeals: true }, roomId);
  await call(hostUid, 'add_question', {
    theme: 'Appeals',
    text: 'Appeal accept',
    answer: 'A',
    cost: 100,
    round: 1,
    type: 'normal',
    mediaType: 'none',
  }, roomId);
  await call(hostUid, 'start_game', {}, roomId);
  const qSnap = await roomRef.collection('questions').limit(1).get();
  const qId = qSnap.docs[0].id;
  await call(hostUid, 'pick_question', { questionId: qId }, roomId);
  await call(hostUid, 'open_buzzing', {}, roomId);
  await call(p1Uid, 'buzz', {}, roomId);
  await call(p1Uid, 'submit_answer', {}, roomId);

  await call(hostUid, 'judge_answer', { correct: false }, roomId);
  let room = (await roomRef.get()).data() || {};
  const p1Before = (await roomRef.collection('players').doc(p1Uid).get()).data() || {};
  assert.equal(String(room.phase), 'answer_review');
  assert.equal(Boolean(room.appealActive), true);
  assert.equal(String(room.appealForUid), p1Uid);
  assert.equal(Number(p1Before.score || 0), 0);

  await call(p2Uid, 'submit_appeal', {}, roomId);
  await call(hostUid, 'resolve_appeal', { accepted: true }, roomId);
  room = (await roomRef.get()).data() || {};
  const p1After = (await roomRef.collection('players').doc(p1Uid).get()).data() || {};
  assert.ok(String(room.phase) === 'board_select' || String(room.phase) === 'final_setup');
  assert.equal(Boolean(room.appealActive), false);
  assert.equal(Number(p1After.score || 0), 100);
  assert.equal(Number(p1After.correctAnswers || 0), 1);
  assert.equal(Number(p1After.wrongAnswers || 0), 0);
});

test('appeal rejected applies penalty and reopens question when players remain', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-appeal-reject-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostAppealReject' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1AppealReject' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2AppealReject' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const created = await call(hostUid, 'create_room', { roomName: 'AppealRejectRoom' });
  const roomId = created.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', {}, roomId);
  await call(p2Uid, 'join_room', {}, roomId);
  await call(hostUid, 'update_room_rules', { useAppeals: true }, roomId);
  await call(hostUid, 'add_question', {
    theme: 'Appeals',
    text: 'Appeal reject',
    answer: 'A',
    cost: 100,
    round: 1,
    type: 'normal',
    mediaType: 'none',
  }, roomId);
  await call(hostUid, 'start_game', {}, roomId);
  const qSnap = await roomRef.collection('questions').limit(1).get();
  const qId = qSnap.docs[0].id;
  await call(hostUid, 'pick_question', { questionId: qId }, roomId);
  await call(hostUid, 'open_buzzing', {}, roomId);
  await call(p1Uid, 'buzz', {}, roomId);
  await call(p1Uid, 'submit_answer', {}, roomId);

  await call(hostUid, 'judge_answer', { correct: false }, roomId);
  await call(p2Uid, 'submit_appeal', {}, roomId);
  await call(hostUid, 'resolve_appeal', { accepted: false }, roomId);

  const room = (await roomRef.get()).data() || {};
  const p1After = (await roomRef.collection('players').doc(p1Uid).get()).data() || {};
  assert.equal(String(room.phase), 'answering');
  assert.equal(Boolean(room.appealActive), false);
  assert.equal(String(room.currentAttemptUid || ''), '');
  assert.equal(Number(p1After.score || 0), -100);
  assert.equal(Number(p1After.wrongAnswers || 0), 1);
});

test('appeal window auto-resolves as rejected on timer expiration', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-appeal-timeout-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostAppealTimeout' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1AppealTimeout' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2AppealTimeout' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const created = await call(hostUid, 'create_room', { roomName: 'AppealTimeoutRoom' });
  const roomId = created.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', {}, roomId);
  await call(p2Uid, 'join_room', {}, roomId);
  await call(hostUid, 'update_room_rules', { useAppeals: true }, roomId);
  await call(hostUid, 'add_question', {
    theme: 'Appeals',
    text: 'Appeal timeout',
    answer: 'A',
    cost: 100,
    round: 1,
    type: 'normal',
    mediaType: 'none',
  }, roomId);
  await call(hostUid, 'start_game', {}, roomId);
  const qSnap = await roomRef.collection('questions').limit(1).get();
  const qId = qSnap.docs[0].id;
  await call(hostUid, 'pick_question', { questionId: qId }, roomId);
  await call(hostUid, 'open_buzzing', {}, roomId);
  await call(p1Uid, 'buzz', {}, roomId);
  await call(p1Uid, 'submit_answer', {}, roomId);
  await call(hostUid, 'judge_answer', { correct: false }, roomId);

  await roomRef.update({
    timerDeadlineAtMs: Date.now() - 1000,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await call(hostUid, 'handle_timer_expiration', {}, roomId);

  const room = (await roomRef.get()).data() || {};
  const p1After = (await roomRef.collection('players').doc(p1Uid).get()).data() || {};
  assert.equal(String(room.phase), 'answering');
  assert.equal(Boolean(room.appealActive), false);
  assert.equal(Number(p1After.score || 0), -100);
  assert.equal(Number(p1After.wrongAnswers || 0), 1);
});

test('for_all collects answers from all players then host judges sequentially', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-for-all-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostForAll' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1ForAll' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2ForAll' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const created = await call(hostUid, 'create_room', { roomName: 'ForAllRoom' });
  const roomId = created.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', {}, roomId);
  await call(p2Uid, 'join_room', {}, roomId);
  await call(hostUid, 'add_question', {
    theme: 'ForAll',
    text: 'Everyone answers',
    answer: 'A',
    cost: 100,
    round: 1,
    type: 'for_all',
    mediaType: 'none',
  }, roomId);
  await call(hostUid, 'start_game', {}, roomId);

  const qSnap = await roomRef.collection('questions').limit(1).get();
  const qId = qSnap.docs[0].id;
  await call(hostUid, 'pick_question', { questionId: qId }, roomId);

  let room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'answering');
  assert.equal(Boolean(room.forAllMode), true);

  await call(p1Uid, 'submit_answer', {}, roomId);
  await call(p2Uid, 'submit_answer', {}, roomId);
  await call(hostUid, 'submit_answer', {}, roomId);

  room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'answer_review');
  assert.equal(Boolean(room.forAllMode), true);
  assert.ok(Array.isArray(room.forAllReviewOrder));
  assert.ok(room.forAllReviewOrder.length >= 3);

  while (String(room.phase) === 'answer_review') {
    await call(hostUid, 'judge_answer', { correct: true }, roomId);
    room = (await roomRef.get()).data() || {};
  }
  assert.ok(
    String(room.phase) === 'board_select' || String(room.phase) === 'final_setup',
  );
  assert.equal(Boolean(room.forAllMode), false);
});

test('stake_all behaves as for_all mode with sequential host judging', { skip: !hasEmulator }, async () => {
  const { gameCommandHandler } = require('../index');
  const db = admin.firestore();

  const hostUid = `host-stake-all-${Date.now()}`;
  const p1Uid = `${hostUid}-p1`;
  const p2Uid = `${hostUid}-p2`;
  await Promise.all([
    db.collection('profiles').doc(hostUid).set({ nickname: 'HostStakeAll' }),
    db.collection('profiles').doc(p1Uid).set({ nickname: 'P1StakeAll' }),
    db.collection('profiles').doc(p2Uid).set({ nickname: 'P2StakeAll' }),
  ]);

  const call = (uid, command, data = {}, roomId = undefined) => {
    const payload = { command, data };
    if (roomId) payload.roomId = roomId;
    return gameCommandHandler(payload, { auth: { uid } });
  };

  const created = await call(hostUid, 'create_room', { roomName: 'StakeAllRoom' });
  const roomId = created.roomId;
  const roomRef = db.collection('rooms').doc(roomId);
  await call(p1Uid, 'join_room', {}, roomId);
  await call(p2Uid, 'join_room', {}, roomId);
  await call(hostUid, 'add_question', {
    theme: 'StakeAll',
    text: 'All stake mode',
    answer: 'A',
    cost: 200,
    round: 1,
    type: 'stake_all',
    mediaType: 'none',
  }, roomId);
  await call(hostUid, 'start_game', {}, roomId);

  const qSnap = await roomRef.collection('questions').limit(1).get();
  const qId = qSnap.docs[0].id;
  await call(hostUid, 'pick_question', { questionId: qId }, roomId);

  let room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'answering');
  assert.equal(Boolean(room.forAllMode), true);
  assert.equal(String(room.activeQuestion?.kind || ''), 'stake_all');

  await call(p1Uid, 'submit_answer', {}, roomId);
  await call(p2Uid, 'submit_answer', {}, roomId);
  await call(hostUid, 'submit_answer', {}, roomId);
  room = (await roomRef.get()).data() || {};
  assert.equal(String(room.phase), 'answer_review');

  while (String(room.phase) === 'answer_review') {
    await call(hostUid, 'judge_answer', { correct: false }, roomId);
    room = (await roomRef.get()).data() || {};
  }

  assert.ok(
    String(room.phase) === 'board_select' || String(room.phase) === 'final_setup',
  );
  assert.equal(Boolean(room.forAllMode), false);
});
