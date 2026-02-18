import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

final bootstrapProvider = FutureProvider<void>((ref) async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
  final uid = auth.currentUser!.uid;
  final prefs = await ref.read(sharedPreferencesProvider.future);
  final nickname = prefs.getString('profile_nickname')?.trim() ?? '';
  final avatarUrl = prefs.getString('profile_avatar') ?? '';

  if (nickname.isNotEmpty) {
    try {
      await ref
          .read(gameRepositoryProvider)
          .upsertProfile(uid: uid, nickname: nickname, avatarUrl: avatarUrl);
    } catch (error, stackTrace) {
      debugPrint('bootstrap upsertProfile failed: $error');
      debugPrint('$stackTrace');
    }
  }
});
