import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_providers.dart';
import '../../game_models.dart';
import 'room_screen.dart';

class RoomEditorScreen extends ConsumerStatefulWidget {
  const RoomEditorScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomEditorScreen> createState() => _RoomEditorScreenState();
}

class _RoomEditorScreenState extends ConsumerState<RoomEditorScreen> {
  final _themeCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _costCtrl = TextEditingController(text: '100');
  int _round = 1;
  QuestionType _type = QuestionType.normal;

  @override
  void dispose() {
    _themeCtrl.dispose();
    _textCtrl.dispose();
    _answerCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.read(gameActionsControllerProvider.notifier);
    final questionsAsync = ref.watch(questionsStreamProvider(widget.roomId));
    return Scaffold(
      appBar: AppBar(title: const Text('Темы и вопросы')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Комната: ${widget.roomId}'),
            const SizedBox(height: 8),
            TextField(
              controller: _themeCtrl,
              decoration: const InputDecoration(labelText: 'Тема'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textCtrl,
              decoration: const InputDecoration(labelText: 'Вопрос'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _answerCtrl,
              decoration: const InputDecoration(labelText: 'Ответ'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Стоимость'),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _round,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Раунд 1')),
                    DropdownMenuItem(value: 2, child: Text('Раунд 2')),
                  ],
                  onChanged: (v) => setState(() => _round = v ?? 1),
                ),
                const SizedBox(width: 8),
                DropdownButton<QuestionType>(
                  value: _type,
                  items: QuestionType.values
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _type = v ?? QuestionType.normal),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await actions.addQuestion(
                        roomId: widget.roomId,
                        draft: QuestionDraft(
                          theme: _themeCtrl.text.trim(),
                          text: _textCtrl.text.trim(),
                          answer: _answerCtrl.text.trim(),
                          cost: int.tryParse(_costCtrl.text.trim()) ?? 100,
                          round: _round,
                          type: _type,
                        ),
                      );
                      _textCtrl.clear();
                      _answerCtrl.clear();
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Вопрос добавлен')),
                      );
                    },
                    child: const Text('Добавить вопрос'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: questionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    Center(child: Text('Ошибка: $error')),
                data: (questions) {
                  if (questions.isEmpty) {
                    return const Center(child: Text('Вопросов нет'));
                  }
                  return ListView.builder(
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      return ListTile(
                        title: Text(
                          'R${q.round} | ${q.theme} | ${q.cost} | ${q.type.label}',
                        ),
                        subtitle: Text(q.text),
                        trailing: q.used
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await actions.joinRoom(widget.roomId);
                      if (!context.mounted) return;
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => RoomScreen(roomId: widget.roomId),
                        ),
                      );
                    },
                    child: const Text('Перейти в комнату'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
