import 'package:flutter/services.dart';

import 'shared_prefs_cache.dart';

class AppHotkeys {
  static const _answerKeyIdPref = 'setting_answer_hotkey_key_id';
  static const LogicalKeyboardKey defaultAnswerHotkey =
      LogicalKeyboardKey.space;

  static Future<LogicalKeyboardKey> loadAnswerHotkey() async {
    final prefs = await getSharedPreferencesCached();
    final keyId = prefs.getInt(_answerKeyIdPref);
    if (keyId == null) {
      return defaultAnswerHotkey;
    }
    return LogicalKeyboardKey.findKeyByKeyId(keyId) ?? defaultAnswerHotkey;
  }

  static Future<void> saveAnswerHotkey(LogicalKeyboardKey key) async {
    final prefs = await getSharedPreferencesCached();
    await prefs.setInt(_answerKeyIdPref, key.keyId);
  }
}
