import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppHotkeys {
  static const _answerKeyIdPref = 'setting_answer_hotkey_key_id';
  static const LogicalKeyboardKey defaultAnswerHotkey =
      LogicalKeyboardKey.space;

  static Future<LogicalKeyboardKey> loadAnswerHotkey() async {
    final prefs = await SharedPreferences.getInstance();
    final keyId = prefs.getInt(_answerKeyIdPref);
    if (keyId == null) {
      return defaultAnswerHotkey;
    }
    return LogicalKeyboardKey.findKeyByKeyId(keyId) ?? defaultAnswerHotkey;
  }

  static Future<void> saveAnswerHotkey(LogicalKeyboardKey key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_answerKeyIdPref, key.keyId);
  }
}
