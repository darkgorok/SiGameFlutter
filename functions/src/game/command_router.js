function createCommandRouter(deps) {
  const {
    functionsLib,
    assertRoomActor,
    metaCommandHandlers,
    roomCommandHandlers,
    contentCommandHandlers,
    gameplayCommandHandlers,
  } = deps;

  return async function routeCommand({
    command,
    uid,
    payload,
    roomId,
    roomRef,
  }) {
    const metaHandler = metaCommandHandlers[command];
    if (metaHandler) {
      return metaHandler({
        uid,
        payload,
      });
    }

    if (!roomId) {
      throw new functionsLib.https.HttpsError('invalid-argument', 'roomId required');
    }

    const roomHandler = roomCommandHandlers[command];
    if (roomHandler) {
      if (command !== 'join_room') {
        await assertRoomActor(roomRef, uid);
      }
      return roomHandler({
        uid,
        payload,
        roomId,
        roomRef,
      });
    }

    const contentHandler = contentCommandHandlers[command];
    if (contentHandler) {
      await assertRoomActor(roomRef, uid);
      return contentHandler({
        uid,
        payload,
        roomId,
        roomRef,
      });
    }

    const gameplayHandler = gameplayCommandHandlers[command];
    if (gameplayHandler) {
      await assertRoomActor(roomRef, uid);
      return gameplayHandler({
        uid,
        payload,
        roomId,
        roomRef,
      });
    }

    throw new functionsLib.https.HttpsError('invalid-argument', `Unknown command: ${command}`);
  };
}

module.exports = {
  createCommandRouter,
};
