const admin = require('firebase-admin');
const functions = require('firebase-functions/v1');
const { createGameBootstrap } = require('./src/game/bootstrap');

admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue ||
  admin.firestore().constructor.FieldValue;

const { gameCommandHandler, serverTimerTickHandler } = createGameBootstrap({
  db,
  FieldValue,
  functionsLib: functions,
});

exports.gameCommandHandler = gameCommandHandler;
exports.gameCommand = functions.https.onCall(gameCommandHandler);

exports.serverTimerTick = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(serverTimerTickHandler);
