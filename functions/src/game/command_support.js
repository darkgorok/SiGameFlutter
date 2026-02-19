function createCommandSupport(deps) {
  const {
    db,
    FieldValue,
    functionsLib,
    PLAYER_ROLE,
    featureFlagsDefaults,
    featureFlagsTtlMs,
  } = deps;

  let featureFlagsCache = null;
  let featureFlagsCacheAtMs = 0;
  const eventMessagesByType = {
    room_created: 'Room created',
    join: 'Player joined room',
    role_change: 'Player role changed',
    kick: 'Player kicked',
    ban: 'Player banned',
    unban: 'Player unbanned',
    rules_update: 'Room rules updated',
    start: 'Game started',
    round_next: 'Round advanced',
    final_start: 'Final round started',
    final_question_set: 'Final question set',
    final_theme_deleter_selected: 'Final theme deleter selected',
    final_theme_deleted: 'Final theme deleted',
    final_wager_open: 'Final wagers opened',
    final_answers_open: 'Final answers stage opened',
    final_answer_submit: 'Final answer submitted',
    final_wager: 'Final wager submitted',
    final_mark: 'Final answer result marked',
    final_reveal_start: 'Final reveal started',
    final_reveal_step: 'Final reveal step',
    final_reveal_end: 'Final reveal finished',
    question_pick: 'Question picked',
    question_add: 'Question added',
    question_add_bulk: 'Questions added in bulk',
    question_update: 'Question updated',
    question_delete: 'Question deleted',
    pack_save: 'Pack saved',
    pack_apply: 'Pack applied to room',
    buzz_open: 'Buzz button opened',
    cat_target: 'Cat in a bag target selected',
    wager_set: 'Wager set',
    buzz: 'Player buzzed',
    answer_submit: 'Voice answer submitted',
    answer_submit_numeric: 'Numeric answer submitted',
    judge: 'Host judged the answer',
    appeal_submit: 'Appeal submitted',
    appeal_resolve: 'Appeal resolved',
    score_manual: 'Manual score adjustment',
    pause: 'Game paused',
    resume: 'Game resumed',
    timer_expire: 'Timer expired',
  };

  async function getProfile(uid) {
    const snap = await db.collection('profiles').doc(uid).get();
    return snap.data() || {};
  }

  async function getPlayerRole(roomRef, uid, tx = null) {
    const playerRef = roomRef.collection('players').doc(uid);
    const snap = tx ? await tx.get(playerRef) : await playerRef.get();
    return snap.data()?.role || null;
  }

  async function assertRoomMember(roomRef, uid, tx = null) {
    const role = await getPlayerRole(roomRef, uid, tx);
    if (!role) {
      throw new functionsLib.https.HttpsError('permission-denied', 'Only room member');
    }
    return role;
  }

  async function assertRoomActor(roomRef, uid, tx = null) {
    const role = await getPlayerRole(roomRef, uid, tx);
    if (role) {
      return role;
    }
    const roomSnap = tx ? await tx.get(roomRef) : await roomRef.get();
    if (roomSnap.exists && roomSnap.data()?.hostUid === uid) {
      return PLAYER_ROLE.HOST;
    }
    throw new functionsLib.https.HttpsError('permission-denied', 'Only room member');
  }

  function canEditContent(role) {
    return role === PLAYER_ROLE.HOST || role === PLAYER_ROLE.EDITOR;
  }

  async function logEvent(roomId, actorUid, type, message) {
    const fallback = String(type || 'system').trim() || 'system';
    const normalizedType = fallback.toLowerCase();
    const canonicalMessage = eventMessagesByType[normalizedType];
    const effectiveMessage = canonicalMessage || String(message || '').trim() || fallback;

    await db.collection('rooms').doc(roomId).collection('events').add({
      actorUid,
      type: fallback,
      message: effectiveMessage,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  async function loadFeatureFlags() {
    const now = Date.now();
    if (featureFlagsCache && now - featureFlagsCacheAtMs < featureFlagsTtlMs) {
      return featureFlagsCache;
    }
    const snap = await db.collection('config').doc('feature_flags').get();
    const data = snap.data() || {};
    featureFlagsCache = { ...featureFlagsDefaults, ...data };
    featureFlagsCacheAtMs = now;
    return featureFlagsCache;
  }

  async function isFeatureEnabled(flagKey) {
    const flags = await loadFeatureFlags();
    return Boolean(flags[flagKey]);
  }

  function logCommandTelemetry({
    command,
    roomId,
    uid,
    ok,
    durationMs,
    errorCode,
  }) {
    const payload = {
      event: 'game_command',
      command,
      roomId: roomId || null,
      uid,
      ok,
      durationMs,
      errorCode: errorCode || null,
      timestamp: new Date().toISOString(),
    };
    console.log(JSON.stringify(payload));
  }

  function requireAuth(context) {
    if (!context.auth?.uid) {
      throw new functionsLib.https.HttpsError('unauthenticated', 'Auth required');
    }
    return context.auth.uid;
  }

  async function requireHost(roomRef, uid, tx = null) {
    const roomSnap = tx ? await tx.get(roomRef) : await roomRef.get();
    if (!roomSnap.exists) {
      throw new functionsLib.https.HttpsError('not-found', 'Room not found');
    }
    if (roomSnap.data().hostUid !== uid) {
      throw new functionsLib.https.HttpsError('permission-denied', 'Host only');
    }
    return roomSnap;
  }

  return {
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
  };
}

module.exports = {
  createCommandSupport,
};
