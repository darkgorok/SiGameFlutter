import 'package:firebase_core/firebase_core.dart';

const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
const firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
const firebaseMessagingSenderId = String.fromEnvironment(
  'FIREBASE_MESSAGING_SENDER_ID',
);
const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');

bool get firebaseConfigured =>
    firebaseApiKey.isNotEmpty &&
    firebaseProjectId.isNotEmpty &&
    firebaseAppId.isNotEmpty;

Future<void> initializeFirebaseFromEnvironment() async {
  if (!firebaseConfigured) {
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
