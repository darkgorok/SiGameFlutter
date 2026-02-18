function createGameCommandHandler(deps) {
  const {
    db,
    functionsLib,
    requireAuth,
    logCommandTelemetry,
    routeCommand,
  } = deps;

  return async function gameCommandHandler(data, context) {
    const startedAtMs = Date.now();
    let command = String(data?.command || '');
    let roomIdForTelemetry = '';
    let telemetryOk = true;
    let telemetryErrorCode = null;

    try {
      const uid = requireAuth(context);
      const payload = data?.data || {};

      if (!command) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'command required');
      }

      const roomId = String(data?.roomId || payload.roomId || '');
      roomIdForTelemetry = roomId;
      const roomRef = roomId ? db.collection('rooms').doc(roomId) : null;

      return await routeCommand({
        command,
        uid,
        payload,
        roomId,
        roomRef,
      });
    } catch (error) {
      telemetryOk = false;
      telemetryErrorCode = error?.code || 'internal';
      throw error;
    } finally {
      logCommandTelemetry({
        command,
        roomId: roomIdForTelemetry,
        uid: context?.auth?.uid || null,
        ok: telemetryOk,
        durationMs: Date.now() - startedAtMs,
        errorCode: telemetryErrorCode,
      });
    }
  };
}

module.exports = {
  createGameCommandHandler,
};
