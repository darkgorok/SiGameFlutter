import 'package:flutter/material.dart';
import '../../app/presentation/loading_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _thinkCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _finalCtrl = TextEditingController();

  @override
  void dispose() {
    _thinkCtrl.dispose();
    _answerCtrl.dispose();
    _finalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(localSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: settingsAsync.when(
        data: (settings) {
          if (_thinkCtrl.text.isEmpty) {
            _thinkCtrl.text = settings.questionThinkSeconds.toString();
            _answerCtrl.text = settings.answerSeconds.toString();
            _finalCtrl.text = settings.finalThinkSeconds.toString();
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                TextField(
                  controller: _thinkCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Время на вопрос (сек)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _answerCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Время на ответ (сек)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _finalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Финал: время (сек)',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt(
                      'setting_question_think_seconds',
                      int.tryParse(_thinkCtrl.text.trim()) ?? 20,
                    );
                    await prefs.setInt(
                      'setting_answer_seconds',
                      int.tryParse(_answerCtrl.text.trim()) ?? 5,
                    );
                    await prefs.setInt(
                      'setting_final_think_seconds',
                      int.tryParse(_finalCtrl.text.trim()) ?? 45,
                    );
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Настройки сохранены')),
                    );
                    ref.invalidate(localSettingsProvider);
                  },
                  child: const Text('Сохранить локальные настройки'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: LoadingPane()),
        error: (error, stack) => Center(child: Text('Ошибка: $error')),
      ),
    );
  }
}
