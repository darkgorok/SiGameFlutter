import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
const firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
const firebaseMessagingSenderId = String.fromEnvironment(
  'FIREBASE_MESSAGING_SENDER_ID',
);
const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
const useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);
const firebaseEmulatorProjectId = String.fromEnvironment(
  'FIREBASE_EMULATOR_PROJECT_ID',
  defaultValue: 'demo-si-game',
);

bool get firebaseConfigured =>
    useFirebaseEmulators ||
    (firebaseApiKey.isNotEmpty &&
        firebaseProjectId.isNotEmpty &&
        firebaseAppId.isNotEmpty);

Future<void> initializeFirebaseFromEnvironment() async {
  if (!firebaseConfigured) {
    return;
  }
  if (useFirebaseEmulators) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: firebaseApiKey.isNotEmpty ? firebaseApiKey : 'demo-api-key',
        authDomain: firebaseAuthDomain.isNotEmpty
            ? firebaseAuthDomain
            : 'localhost',
        projectId: firebaseProjectId.isNotEmpty
            ? firebaseProjectId
            : firebaseEmulatorProjectId,
        storageBucket: firebaseStorageBucket.isNotEmpty
            ? firebaseStorageBucket
            : '$firebaseEmulatorProjectId.appspot.com',
        messagingSenderId: firebaseMessagingSenderId.isNotEmpty
            ? firebaseMessagingSenderId
            : '000000000000',
        appId: firebaseAppId.isNotEmpty
            ? firebaseAppId
            : '1:000000000000:web:emulator',
      ),
    );
    return;
  }
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: firebaseApiKey,
      authDomain: firebaseAuthDomain,
      projectId: firebaseProjectId,
      storageBucket: firebaseStorageBucket,
      messagingSenderId: firebaseMessagingSenderId,
      appId: firebaseAppId,
    ),
  );
}

void connectFirebaseEmulatorsIfEnabled() {
  if (!useFirebaseEmulators) {
    return;
  }

  const host = '127.0.0.1';

  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  if (kIsWeb) {
    FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);
  }
  FirebaseAuth.instance.useAuthEmulator(host, 9099);
}
