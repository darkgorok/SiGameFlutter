const crypto = require('crypto');

function hashRoomPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

function createRoomCommandHandlers(deps) {
  const {
    db,
    FieldValue,
    functionsLib,
    PLAYER_ROLE,
    FINAL_RESULT,
    ALLOWED_JOIN_ROLES,
    getProfile,
    requireHost,
    autoHealAfterRosterChange,
    logEvent,
    GAME_TIMER_MS,
  } = deps;

  const TIMER_KEYS = Object.keys(GAME_TIMER_MS);

  function clampTimerMs(value, fallback) {
    const n = Number(value);
    if (!Number.isFinite(n)) {
      return fallback;
    }
    return Math.max(1000, Math.min(Math.floor(n), 180000));
  }

  return {
    async join_room({ uid, payload, roomId, roomRef }) {
      const profile = await getProfile(uid);
      const providedPassword = String(payload.password || '').trim();
      const requestedRole = String(payload.role || PLAYER_ROLE.PLAYER);
      const allowedRole = ALLOWED_JOIN_ROLES.has(requestedRole)
        ? requestedRole
        : PLAYER_ROLE.PLAYER;
      const hasProfileNickname = typeof profile.nickname === 'string';
      const hasProfileAvatarUrl = typeof profile.avatarUrl === 'string';
      const profileNickname = String(profile.nickname || '').trim();
      const profileAvatarUrl = String(profile.avatarUrl || '').trim();

      await db.runTransaction(async (tx) => {
        const roomSnap = await tx.get(roomRef);
        if (!roomSnap.exists) {
          throw new functionsLib.https.HttpsError('not-found', 'Room not found');
        }
        const banSnap = await tx.get(roomRef.collection('bans').doc(uid));
        if (banSnap.exists) {
          throw new functionsLib.https.HttpsError(
            'permission-denied',
            'You are banned in this room',
          );
        }

        const room = roomSnap.data() || {};
        const isHost = room.hostUid === uid;
        const securitySnap = await tx.get(roomRef.collection('meta').doc('security'));
        const storedHash = String(securitySnap.data()?.passwordHash || '').trim();
        const protectedRoom = Boolean(room.passwordProtected) || storedHash.length > 0;
        if (protectedRoom && !isHost) {
          if (!providedPassword) {
            throw new functionsLib.https.HttpsError(
              'failed-precondition',
              'Room password required',
            );
          }
          const providedHash = hashRoomPassword(providedPassword);
          if (!storedHash || storedHash !== providedHash) {
            throw new functionsLib.https.HttpsError(
              'permission-denied',
              'Invalid room password',
            );
          }
        }

        const playerRef = roomRef.collection('players').doc(uid);
        const playerSnap = await tx.get(playerRef);
        const existing = playerSnap.data() || {};
        const role = isHost ? PLAYER_ROLE.HOST : allowedRole;

        tx.set(
          playerRef,
          {
            nickname: hasProfileNickname
              ? (profileNickname || 'Player')
              : (existing.nickname || 'Player'),
            avatarUrl: hasProfileAvatarUrl
              ? profileAvatarUrl
              : (existing.avatarUrl || ''),
            role,
            connected: true,
            score: playerSnap.exists
              ? FieldValue.increment(0)
              : Number(existing.score || 0),
            isHost,
            correctAnswers: playerSnap.exists
              ? FieldValue.increment(0)
              : Number(existing.correctAnswers || 0),
            wrongAnswers: playerSnap.exists
              ? FieldValue.increment(0)
              : Number(existing.wrongAnswers || 0),
            buzzCount: playerSnap.exists
              ? FieldValue.increment(0)
              : Number(existing.buzzCount || 0),
            finalWager: playerSnap.exists
              ? FieldValue.increment(0)
              : Number(existing.finalWager || 0),
            finalWagerSubmitted: Boolean(existing.finalWagerSubmitted),
            finalAnswerSubmitted: Boolean(existing.finalAnswerSubmitted),
            finalResult: existing.finalResult || FINAL_RESULT.PENDING,
          },
          { merge: true },
        );
        tx.update(roomRef, { updatedAt: FieldValue.serverTimestamp() });
      });

      await autoHealAfterRosterChange(roomRef, roomId);
      await logEvent(roomId, uid, 'join', 'Player joined room');
      return { ok: true };
    },

    async set_player_role({ uid, payload, roomId, roomRef }) {
      const targetUid = String(payload.targetUid || '');
      const role = String(payload.role || PLAYER_ROLE.PLAYER);
      if (!targetUid || targetUid === uid) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'targetUid required');
      }
      if (!ALLOWED_JOIN_ROLES.has(role)) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'invalid role');
      }

      const roomSnap = await requireHost(roomRef, uid);
      const room = roomSnap.data() || {};
      if (room.hostUid === targetUid) {
        throw new functionsLib.https.HttpsError(
          'failed-precondition',
          'Cannot change host role',
        );
      }

      await roomRef.collection('players').doc(targetUid).set({ role }, { merge: true });
      await autoHealAfterRosterChange(roomRef, roomId);
      await logEvent(roomId, uid, 'role_change', 'Player role changed');
      return { ok: true };
    },

    async kick_player({ uid, payload, roomId, roomRef }) {
      const targetUid = String(payload.targetUid || '');
      if (!targetUid || targetUid === uid) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'targetUid required');
      }

      const roomSnap = await requireHost(roomRef, uid);
      const room = roomSnap.data() || {};
      if (room.hostUid === targetUid) {
        throw new functionsLib.https.HttpsError('failed-precondition', 'Cannot kick host');
      }

      await roomRef.collection('players').doc(targetUid).set(
        { connected: false, kickedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
      await autoHealAfterRosterChange(roomRef, roomId);
      await logEvent(roomId, uid, 'kick', 'Player kicked');
      return { ok: true };
    },

    async ban_player({ uid, payload, roomId, roomRef }) {
      const targetUid = String(payload.targetUid || '');
      const reason = String(payload.reason || '').trim();
      if (!targetUid || targetUid === uid) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'targetUid required');
      }

      const roomSnap = await requireHost(roomRef, uid);
      const room = roomSnap.data() || {};
      if (room.hostUid === targetUid) {
        throw new functionsLib.https.HttpsError('failed-precondition', 'Cannot ban host');
      }

      const batch = db.batch();
      batch.set(
        roomRef.collection('bans').doc(targetUid),
        {
          uid: targetUid,
          reason,
          bannedBy: uid,
          createdAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      batch.set(
        roomRef.collection('players').doc(targetUid),
        { connected: false, role: PLAYER_ROLE.SPECTATOR },
        { merge: true },
      );
      await batch.commit();

      await autoHealAfterRosterChange(roomRef, roomId);
      await logEvent(roomId, uid, 'ban', 'Player banned');
      return { ok: true };
    },

    async unban_player({ uid, payload, roomId, roomRef }) {
      const targetUid = String(payload.targetUid || '');
      if (!targetUid) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'targetUid required');
      }

      await requireHost(roomRef, uid);
      await roomRef.collection('bans').doc(targetUid).delete();
      await autoHealAfterRosterChange(roomRef, roomId);
      await logEvent(roomId, uid, 'unban', 'Player unbanned');
      return { ok: true };
    },

    async mark_disconnected({ uid, roomId, roomRef }) {
      await roomRef.collection('players').doc(uid).set({ connected: false }, { merge: true });
      await autoHealAfterRosterChange(roomRef, roomId);
      return { ok: true };
    },

    async update_room_rules({ uid, payload, roomId, roomRef }) {
      await requireHost(roomRef, uid);
      const incoming = payload && typeof payload === 'object' ? payload : {};
      const incomingTimers = incoming.timers && typeof incoming.timers === 'object'
        ? incoming.timers
        : {};

      const timers = {};
      for (const key of TIMER_KEYS) {
        timers[key] = clampTimerMs(incomingTimers[key], GAME_TIMER_MS[key]);
      }

      await roomRef.set(
        {
          rules: {
            falseStartEnabled: Boolean(incoming.falseStartEnabled),
            useAppeals: Boolean(incoming.useAppeals),
            timers,
          },
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      await logEvent(roomId, uid, 'rules_update', 'Room rules updated');
      return { ok: true };
    },
  };
}

module.exports = {
  createRoomCommandHandlers,
};
