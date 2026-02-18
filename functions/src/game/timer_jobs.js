function createServerTimerTickHandler(deps) {
  const {
    db,
    GAME_STATUS,
    isFeatureEnabled,
    handleTimerExpirationByHost,
  } = deps;

  return async function serverTimerTickHandler() {
    if (!await isFeatureEnabled('timerAutoTick')) {
      return null;
    }
    const now = Date.now();
    const rooms = await db
      .collection('rooms')
      .where('timerDeadlineAtMs', '<=', now)
      .where('status', '!=', GAME_STATUS.PAUSED)
      .limit(50)
      .get();

    for (const room of rooms.docs) {
      const data = room.data();
      const hostUid = data?.hostUid;
      if (!hostUid) {
        continue;
      }
      try {
        await handleTimerExpirationByHost(room.ref, room.id, hostUid);
      } catch (e) {
        console.error('timer tick failed', room.id, e.message);
      }
    }

    return null;
  };
}

module.exports = {
  createServerTimerTickHandler,
};
