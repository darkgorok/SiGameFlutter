import { initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth } from 'firebase/auth';
import { connectFirestoreEmulator, getFirestore } from 'firebase/firestore';
import { connectFunctionsEmulator, getFunctions } from 'firebase/functions';

import { activeFirestoreDatabaseId, appEnv, firebaseConfigured } from '../config/env';

const fallbackOptions = {
  apiKey: appEnv.firebaseApiKey || 'demo-api-key',
  authDomain: appEnv.firebaseAuthDomain || 'localhost',
  projectId: appEnv.firebaseProjectId || appEnv.firebaseEmulatorProjectId,
  storageBucket:
    appEnv.firebaseStorageBucket || `${appEnv.firebaseEmulatorProjectId}.appspot.com`,
  messagingSenderId: appEnv.firebaseMessagingSenderId || '000000000000',
  appId: appEnv.firebaseAppId || '1:000000000000:web:placeholder',
};

const firebaseApp = initializeApp(
  appEnv.useFirebaseEmulators || !firebaseConfigured
    ? fallbackOptions
    : {
        apiKey: appEnv.firebaseApiKey,
        authDomain: appEnv.firebaseAuthDomain,
        projectId: appEnv.firebaseProjectId,
        storageBucket: appEnv.firebaseStorageBucket,
        messagingSenderId: appEnv.firebaseMessagingSenderId,
        appId: appEnv.firebaseAppId,
      },
);

export const auth = getAuth(firebaseApp);
export const db = getFirestore(firebaseApp, activeFirestoreDatabaseId);
const functionsRegion = appEnv.useFirebaseEmulators ? 'us-central1' : appEnv.firebaseFunctionsRegion;
export const functions = getFunctions(firebaseApp, functionsRegion);

let emulatorsConnected = false;

export function connectFirebaseEmulatorsIfEnabled(): void {
  if (emulatorsConnected || !appEnv.useFirebaseEmulators) {
    return;
  }
  const host = '127.0.0.1';
  connectFirestoreEmulator(db, host, 8080);
  connectFunctionsEmulator(functions, host, 5001);
  connectAuthEmulator(auth, `http://${host}:9099`, { disableWarnings: true });
  emulatorsConnected = true;
}

export { firebaseConfigured };
