import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/game/data/game_repository.dart';
import '../features/game/data/game_repository_impl.dart';
import '../features/game/game_service.dart';
import '../features/settings/local_settings.dart';

final gameServiceProvider = Provider<GameService>((ref) {
  return GameService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    functions: FirebaseFunctions.instance,
  );
});

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepositoryImpl(ref.watch(gameServiceProvider));
});

final localSettingsProvider = FutureProvider<LocalSettings>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return LocalSettings.fromPrefs(prefs);
});
