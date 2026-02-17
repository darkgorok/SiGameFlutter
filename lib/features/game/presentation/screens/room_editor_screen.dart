import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../../app/presentation/loading_screen.dart';
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
  final _aliasesCtrl = TextEditingController();
  final _costCtrl = TextEditingController(text: '100');
  final _mediaUrlCtrl = TextEditingController();
  final _packNameCtrl = TextEditingController(text: 'Мой пак');
  int _round = 1;
  QuestionType _type = QuestionType.normal;
  QuestionMediaType _mediaType = QuestionMediaType.none;

  @override
  void dispose() {
    _themeCtrl.dispose();
    _textCtrl.dispose();
    _answerCtrl.dispose();
    _aliasesCtrl.dispose();
    _costCtrl.dispose();
    _mediaUrlCtrl.dispose();
    _packNameCtrl.dispose();
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
              decoration: const InputDecoration(
                labelText: 'Ответ (для ведущего)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _aliasesCtrl,
              decoration: const InputDecoration(
                labelText: 'Варианты ответа (через запятую)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mediaUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Ссылка на медиа (опционально)',
              ),
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
                const SizedBox(width: 8),
                DropdownButton<QuestionMediaType>(
                  value: _mediaType,
                  items: QuestionMediaType.values
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _mediaType = v ?? QuestionMediaType.none),
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
                          mediaUrl: _mediaUrlCtrl.text.trim(),
                          mediaType: _mediaType,
                          aliases: _parseAliases(_aliasesCtrl.text),
                        ),
                      );
                      _textCtrl.clear();
                      _answerCtrl.clear();
                      _aliasesCtrl.clear();
                      _mediaUrlCtrl.clear();
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final questions = await ref.read(
                        questionsStreamProvider(widget.roomId).future,
                      );
                      final payload = {
                        'roomId': widget.roomId,
                        'questions': questions
                            .map(
                              (q) => {
                                'theme': q.theme,
                                'text': q.text,
                                'answer': q.answer,
                                'cost': q.cost,
                                'round': q.round,
                                'type': q.type.value,
                                'mediaUrl': q.mediaUrl,
                                'mediaType': q.mediaType.value,
                                'aliases': q.aliases,
                              },
                            )
                            .toList(),
                      };
                      final pretty = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(payload);
                      if (!context.mounted) return;
                      _showJsonDialog(
                        context,
                        title: 'Экспорт пакета',
                        jsonText: pretty,
                        readOnly: true,
                      );
                    },
                    child: const Text('Экспорт JSON'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showImportDialog(context, actions),
                    child: const Text('Импорт JSON'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: questionsAsync.when(
                loading: () => const Center(child: LoadingPane()),
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
                        subtitle: Text(
                          '${q.text}\n${q.mediaUrl.isEmpty ? '' : 'Медиа: ${q.mediaType.label}'}',
                        ),
                        isThreeLine: q.mediaUrl.isNotEmpty,
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
                  child: TextField(
                    controller: _packNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Название пака',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final result = await actions.savePack(
                      roomId: widget.roomId,
                      name: _packNameCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Пак сохранен v${result.version}'),
                      ),
                    );
                  },
                  child: const Text('Сохранить пак'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showPacksDialog(context, actions),
                    child: const Text('Каталог паков'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await actions.joinRoom(
                        widget.roomId,
                        role: PlayerRole.editor,
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => RoomScreen(
                            roomId: widget.roomId,
                            role: PlayerRole.editor,
                          ),
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

  List<String> _parseAliases(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _showPacksDialog(
    BuildContext context,
    GameActionsController actions,
  ) async {
    final packs = await actions.listPacks();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Каталог паков'),
          content: SizedBox(
            width: 700,
            child: packs.isEmpty
                ? const Text('Паков нет')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: packs.length,
                    itemBuilder: (context, index) {
                      final p = packs[index];
                      return ListTile(
                        title: Text('${p.name} v${p.version}'),
                        subtitle: Text('Вопросов: ${p.questionCount}'),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await actions.applyPack(
                              roomId: widget.roomId,
                              packId: p.id,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                          child: const Text('Применить'),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showImportDialog(
    BuildContext context,
    GameActionsController actions,
  ) async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Импорт пакета JSON'),
          content: SizedBox(
            width: 700,
            child: TextField(
              controller: ctrl,
              maxLines: 20,
              decoration: const InputDecoration(
                hintText: 'Вставьте JSON с questions',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final raw = jsonDecode(ctrl.text);
                  final list = raw is List
                      ? raw
                      : (raw is Map<String, dynamic>
                            ? (raw['questions'] as List? ?? const [])
                            : const []);
                  for (final item in list) {
                    if (item is! Map) continue;
                    final map = Map<String, dynamic>.from(item);
                    await actions.addQuestion(
                      roomId: widget.roomId,
                      draft: QuestionDraft(
                        theme: (map['theme'] as String? ?? '').trim(),
                        text: (map['text'] as String? ?? '').trim(),
                        answer: (map['answer'] as String? ?? '').trim(),
                        cost: (map['cost'] as num?)?.toInt() ?? 100,
                        round: (map['round'] as num?)?.toInt() ?? 1,
                        type: QuestionType.fromValue(map['type'] as String?),
                        mediaUrl: (map['mediaUrl'] as String? ?? '').trim(),
                        mediaType: QuestionMediaType.fromValue(
                          map['mediaType'] as String?,
                        ),
                        aliases: ((map['aliases'] as List?) ?? [])
                            .whereType<String>()
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
                      ),
                    );
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Ошибка импорта: $e')));
                }
              },
              child: const Text('Импортировать'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showJsonDialog(
    BuildContext context, {
    required String title,
    required String jsonText,
    required bool readOnly,
  }) async {
    final ctrl = TextEditingController(text: jsonText);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 700,
            child: TextField(
              controller: ctrl,
              readOnly: readOnly,
              maxLines: 20,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }
}
