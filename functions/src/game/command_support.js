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
    await db.collection('rooms').doc(roomId).collection('events').add({
      actorUid,
      type,
      message,
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
