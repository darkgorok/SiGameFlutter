import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_prefs_cache.dart';
import 'firebase_config.dart';
import '../features/game/data/game_repository.dart';
import '../features/game/data/game_repository_impl.dart';
import '../features/game/game_service.dart';
import '../features/settings/local_settings.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return getSharedPreferencesCached();
});

final gameServiceProvider = Provider<GameService>((ref) {
  return GameService(
    firestore: FirebaseFirestore.instanceFor(
      app: FirebaseAuth.instance.app,
      databaseId: activeFirestoreDatabaseId,
    ),
    auth: FirebaseAuth.instance,
    functions: FirebaseFunctions.instanceFor(region: firebaseFunctionsRegion),
  );
});

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepositoryImpl(ref.watch(gameServiceProvider));
});

final localSettingsProvider = FutureProvider<LocalSettings>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return LocalSettings.fromPrefs(prefs);
});

final profileStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, uid) {
      return FirebaseFirestore.instanceFor(
            app: FirebaseAuth.instance.app,
            databaseId: activeFirestoreDatabaseId,
          )
          .collection('profiles')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.data() ?? <String, dynamic>{});
    });

final currentUserUidProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});
