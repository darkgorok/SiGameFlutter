import 'package:shared_preferences/shared_preferences.dart';

class LocalSettings {
  LocalSettings({
    required this.questionThinkSeconds,
    required this.answerSeconds,
    required this.finalThinkSeconds,
  });

  final int questionThinkSeconds;
  final int answerSeconds;
  final int finalThinkSeconds;

  factory LocalSettings.fromPrefs(SharedPreferences prefs) {
    return LocalSettings(
      questionThinkSeconds:
          prefs.getInt('setting_question_think_seconds') ?? 20,
      answerSeconds: prefs.getInt('setting_answer_seconds') ?? 5,
      finalThinkSeconds: prefs.getInt('setting_final_think_seconds') ?? 45,
    );
  }
}
