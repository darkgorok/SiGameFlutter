export type AppEnv = {
  firebaseApiKey: string;
  firebaseAuthDomain: string;
  firebaseProjectId: string;
  firebaseStorageBucket: string;
  firebaseMessagingSenderId: string;
  firebaseAppId: string;
  firebaseFunctionsRegion: string;
  firebaseFirestoreDatabaseId: string;
  firebaseEmulatorFirestoreDatabaseId: string;
  firebaseEmulatorProjectId: string;
  useFirebaseEmulators: boolean;
};

function read(name: string, fallback = ''): string {
  return (import.meta.env[name] as string | undefined)?.trim() ?? fallback;
}

function readBool(name: string, fallback: boolean): boolean {
  const value = (import.meta.env[name] as string | undefined)?.trim().toLowerCase();
  if (value === 'true') return true;
  if (value === 'false') return false;
  return fallback;
}

export const appEnv: AppEnv = {
  firebaseApiKey: read('VITE_FIREBASE_API_KEY'),
  firebaseAuthDomain: read('VITE_FIREBASE_AUTH_DOMAIN'),
  firebaseProjectId: read('VITE_FIREBASE_PROJECT_ID'),
  firebaseStorageBucket: read('VITE_FIREBASE_STORAGE_BUCKET'),
  firebaseMessagingSenderId: read('VITE_FIREBASE_MESSAGING_SENDER_ID'),
  firebaseAppId: read('VITE_FIREBASE_APP_ID'),
  firebaseFunctionsRegion: read('VITE_FIREBASE_FUNCTIONS_REGION', 'us-central1'),
  firebaseFirestoreDatabaseId: read('VITE_FIREBASE_FIRESTORE_DATABASE_ID', 'databasewarsaw'),
  firebaseEmulatorFirestoreDatabaseId: read('VITE_FIREBASE_EMULATOR_FIRESTORE_DATABASE_ID', '(default)'),
  firebaseEmulatorProjectId: read('VITE_FIREBASE_EMULATOR_PROJECT_ID', 'demo-si-game'),
  useFirebaseEmulators: readBool('VITE_USE_FIREBASE_EMULATORS', false),
};

export const firebaseConfigured =
  appEnv.useFirebaseEmulators ||
  (appEnv.firebaseApiKey.length > 0 &&
    appEnv.firebaseProjectId.length > 0 &&
    appEnv.firebaseAppId.length > 0);

export const activeFirestoreDatabaseId = appEnv.useFirebaseEmulators
  ? appEnv.firebaseEmulatorFirestoreDatabaseId
  : appEnv.firebaseFirestoreDatabaseId;
