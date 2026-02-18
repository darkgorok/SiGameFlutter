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
  await call(hostUid, 'judge_answer', { correct: true }, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'board_select');
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
  assert.equal(room.phase, 'board_select');
  assert.equal(room.currentQuestionId, null);

  assert.deepEqual(
    [...seenTypes].sort(),
    ['cat_in_bag', 'closest_number', 'normal', 'wager'],
  );
  assert.deepEqual(
    [...seenMediaTypes].sort(),
    ['audio', 'image', 'none', 'video'],
  );

  let p1 = await readPlayer(player1Uid);
  let p2 = await readPlayer(player2Uid);
  assert.equal(p1.score, 800);
  assert.equal(p2.score, -200);

  await call(hostUid, 'apply_score', { targetUid: player2Uid, delta: 500 }, roomId);
  p2 = await readPlayer(player2Uid);
  assert.equal(p2.score, 300);

  await call(hostUid, 'advance_round2', {}, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'board_select');
  assert.equal(room.currentRound, 2);

  await call(hostUid, 'start_final_round', {}, roomId);
  room = await readRoom();
  assert.equal(room.status, 'final_round');
  assert.equal(room.phase, 'final_setup');
  assert.equal(room.currentRound, 3);
  assert.ok(Array.isArray(room.finalEligibleUids));
  assert.ok(room.finalEligibleUids.includes(player1Uid));
  assert.ok(room.finalEligibleUids.includes(player2Uid));

  await call(
    hostUid,
    'set_final_question',
    { theme: 'Final Theme', question: 'Final Q', answer: 'Final A' },
    roomId,
  );

  await call(hostUid, 'open_final_wagers', {}, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'final_wagering');

  await call(player1Uid, 'submit_final_wager', { wager: 300 }, roomId);
  await call(player2Uid, 'submit_final_wager', { wager: 200 }, roomId);

  await call(hostUid, 'open_final_answers', {}, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'final_answering');

  await call(
    hostUid,
    'set_final_player_result',
    { targetUid: player1Uid, result: 'correct' },
    roomId,
  );
  await call(
    hostUid,
    'set_final_player_result',
    { targetUid: player2Uid, result: 'wrong' },
    roomId,
  );

  await call(hostUid, 'reveal_final', {}, roomId);
  room = await readRoom();
  assert.equal(room.phase, 'game_over');
  assert.equal(room.status, 'completed');

  p1 = await readPlayer(player1Uid);
  p2 = await readPlayer(player2Uid);

  assert.equal(p1.finalWager, 300);
  assert.equal(p1.finalResult, 'correct');
  assert.equal(p1.score, 1100);

  assert.equal(p2.finalWager, 200);
  assert.equal(p2.finalResult, 'wrong');
  assert.equal(p2.score, 100);
});
