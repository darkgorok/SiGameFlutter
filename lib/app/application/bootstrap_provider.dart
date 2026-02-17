import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';

final bootstrapProvider = FutureProvider<void>((ref) async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
  final uid = auth.currentUser!.uid;
  final prefs = await SharedPreferences.getInstance();
  final nickname =
      prefs.getString('profile_nickname') ??
      'Игрок-${uid.substring(0, 5).toUpperCase()}';
  final avatarUrl = prefs.getString('profile_avatar') ?? '';

  await ref
      .read(gameRepositoryProvider)
      .upsertProfile(uid: uid, nickname: nickname, avatarUrl: avatarUrl);
});
