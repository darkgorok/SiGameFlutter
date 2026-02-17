import 'dart:convert';

import 'package:flutter/material.dart';

import '../game/game_models.dart';
import 'local_pack.dart';
import 'pack_file.dart';

class PackEditorScreen extends StatefulWidget {
  const PackEditorScreen({super.key});

  @override
  State<PackEditorScreen> createState() => _PackEditorScreenState();
}

class _PackEditorScreenState extends State<PackEditorScreen> {
  final _packNameCtrl = TextEditingController(text: 'Новый пак');
  final _themeCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _aliasesCtrl = TextEditingController();
  final _costCtrl = TextEditingController(text: '100');
  final _mediaUrlCtrl = TextEditingController();

  final _bulkThemeCtrl = TextEditingController();

  final List<LocalPackQuestion> _questions = [];
  final Set<int> _selected = <int>{};

  int _round = 1;
  QuestionType _type = QuestionType.normal;
  QuestionMediaType _mediaType = QuestionMediaType.none;
  int? _editingIndex;
  bool _busy = false;

  int? _bulkRound;
  bool _bulkSelectedOnly = true;

  @override
  void dispose() {
    _packNameCtrl.dispose();
    _themeCtrl.dispose();
    _textCtrl.dispose();
    _answerCtrl.dispose();
    _aliasesCtrl.dispose();
    _costCtrl.dispose();
    _mediaUrlCtrl.dispose();
    _bulkThemeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редактор пака')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _packNameCtrl,
              decoration: const InputDecoration(labelText: 'Название пака'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _importFromFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Загрузить файл'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _exportToFile,
                    icon: const Icon(Icons.download),
                    label: const Text('Сохранить в файл'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _clearPack,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Очистить'),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            TextField(
              controller: _themeCtrl,
              decoration: const InputDecoration(labelText: 'Тема'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Вопрос'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _answerCtrl,
              decoration: const InputDecoration(labelText: 'Ответ'),
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _addOrUpdateQuestion,
                    child: Text(
                      _editingIndex == null
                          ? 'Добавить вопрос'
                          : 'Сохранить изменения',
                    ),
                  ),
                ),
                if (_editingIndex != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : _cancelEdit,
                    child: const Text('Отмена'),
                  ),
                ],
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bulkThemeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Массовая тема (опционально)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int?>(
                  value: _bulkRound,
                  items: const [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Раунд: -'),
                    ),
                    DropdownMenuItem<int?>(value: 1, child: Text('Раунд 1')),
                    DropdownMenuItem<int?>(value: 2, child: Text('Раунд 2')),
                  ],
                  onChanged: (v) => setState(() => _bulkRound = v),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _bulkSelectedOnly,
                      onChanged: (v) =>
                          setState(() => _bulkSelectedOnly = v ?? true),
                    ),
                    const Text('Только выбранные'),
                  ],
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _busy ? null : _applyBulkUpdate,
                  child: const Text('Применить'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Вопросов: ${_questions.length} | Выбрано: ${_selected.length}. Перетаскивайте строки для изменения порядка.',
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _questions.isEmpty
                  ? const Center(child: Text('В паке пока нет вопросов'))
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: _questions.length,
                      onReorder: _reorderQuestions,
                      itemBuilder: (context, index) {
                        final q = _questions[index];
                        final selected = _selected.contains(index);
                        return Card(
                          key: ValueKey('q-$index-${q.text.hashCode}'),
                          child: ListTile(
                            leading: Checkbox(
                              value: selected,
                              onChanged: _busy
                                  ? null
                                  : (v) => _toggleSelected(index, v ?? false),
                            ),
                            title: Text(
                              '${index + 1}. R${q.round} | ${q.theme} | ${q.cost} | ${q.type.label}',
                            ),
                            subtitle: Text(q.text),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _editQuestion(index),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _removeQuestion(index),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Icon(Icons.drag_handle),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _addOrUpdateQuestion() {
    final question = LocalPackQuestion(
      theme: _themeCtrl.text.trim(),
      text: _textCtrl.text.trim(),
      answer: _answerCtrl.text.trim(),
      cost: int.tryParse(_costCtrl.text.trim()) ?? 100,
      round: _round,
      type: _type,
      mediaUrl: _mediaUrlCtrl.text.trim(),
      mediaType: _mediaType,
      aliases: _aliasesCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(),
    );

    if (question.theme.isEmpty ||
        question.text.isEmpty ||
        question.answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тема, вопрос и ответ обязательны')),
      );
      return;
    }

    setState(() {
      if (_editingIndex == null) {
        _questions.add(question);
      } else {
        _questions[_editingIndex!] = question;
      }
      _editingIndex = null;
      _clearQuestionInputs();
    });
  }

  void _editQuestion(int index) {
    final q = _questions[index];
    setState(() {
      _editingIndex = index;
      _themeCtrl.text = q.theme;
      _textCtrl.text = q.text;
      _answerCtrl.text = q.answer;
      _aliasesCtrl.text = q.aliases.join(', ');
      _costCtrl.text = q.cost.toString();
      _round = q.round;
      _type = q.type;
      _mediaUrlCtrl.text = q.mediaUrl;
      _mediaType = q.mediaType;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _clearQuestionInputs();
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
      final updated = <int>{};
      for (final i in _selected) {
        if (i == index) continue;
        updated.add(i > index ? i - 1 : i);
      }
      _selected
        ..clear()
        ..addAll(updated);

      if (_editingIndex == index) {
        _editingIndex = null;
        _clearQuestionInputs();
      } else if (_editingIndex != null && _editingIndex! > index) {
        _editingIndex = _editingIndex! - 1;
      }
    });
  }

  void _clearPack() {
    setState(() {
      _questions.clear();
      _selected.clear();
      _editingIndex = null;
      _clearQuestionInputs();
    });
  }

  void _toggleSelected(int index, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(index);
      } else {
        _selected.remove(index);
      }
    });
  }

  void _applyBulkUpdate() {
    if (_questions.isEmpty) {
      return;
    }
    final theme = _bulkThemeCtrl.text.trim();
    final round = _bulkRound;
    if (theme.isEmpty && round == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите тему и/или раунд для массового изменения'),
        ),
      );
      return;
    }

    final targets = _bulkSelectedOnly
        ? (() {
            final list = _selected.toList();
            list.sort();
            return list;
          })()
        : List<int>.generate(_questions.length, (i) => i);

    if (targets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Нет выбранных вопросов')));
      return;
    }

    setState(() {
      for (final i in targets) {
        final q = _questions[i];
        _questions[i] = LocalPackQuestion(
          theme: theme.isEmpty ? q.theme : theme,
          text: q.text,
          answer: q.answer,
          cost: q.cost,
          round: round ?? q.round,
          type: q.type,
          mediaUrl: q.mediaUrl,
          mediaType: q.mediaType,
          aliases: q.aliases,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Обновлено вопросов: ${targets.length}')),
    );
  }

  void _reorderQuestions(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _questions.removeAt(oldIndex);
      _questions.insert(newIndex, item);

      int remap(int index) {
        if (index == oldIndex) return newIndex;
        if (oldIndex < newIndex && index > oldIndex && index <= newIndex) {
          return index - 1;
        }
        if (newIndex < oldIndex && index >= newIndex && index < oldIndex) {
          return index + 1;
        }
        return index;
      }

      final newSelected = _selected.map(remap).toSet();
      _selected
        ..clear()
        ..addAll(newSelected);

      if (_editingIndex != null) {
        _editingIndex = remap(_editingIndex!);
      }
    });
  }

  Future<void> _importFromFile() async {
    setState(() => _busy = true);
    try {
      final jsonText = await pickPackJsonText();
      if (jsonText == null || jsonText.trim().isEmpty) {
        return;
      }
      final raw = jsonDecode(jsonText);
      final pack = LocalPackDocument.fromJson(raw);
      if (!mounted) return;
      setState(() {
        _packNameCtrl.text = pack.name;
        _questions
          ..clear()
          ..addAll(pack.questions);
        _selected.clear();
        _editingIndex = null;
        _clearQuestionInputs();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Импортировано вопросов: ${pack.questions.length}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка импорта: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportToFile() async {
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пак пустой')));
      return;
    }
    setState(() => _busy = true);
    try {
      final pack = LocalPackDocument(
        name: _packNameCtrl.text.trim().isEmpty
            ? 'Новый пак'
            : _packNameCtrl.text.trim(),
        questions: List<LocalPackQuestion>.from(_questions),
      );
      final jsonText = const JsonEncoder.withIndent(
        '  ',
      ).convert(pack.toJson());
      final safeName = pack.name
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(' ', '_');
      final ok = await savePackJsonText(
        suggestedFileName: '${safeName.isEmpty ? 'pack' : safeName}.json',
        content: jsonText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Файл сохранен' : 'Сохранение отменено')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _clearQuestionInputs() {
    _themeCtrl.clear();
    _textCtrl.clear();
    _answerCtrl.clear();
    _aliasesCtrl.clear();
    _costCtrl.text = '100';
    _mediaUrlCtrl.clear();
    _round = 1;
    _type = QuestionType.normal;
    _mediaType = QuestionMediaType.none;
  }
}
