import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/loading_screen.dart';
import '../../../../core/l10n.dart';
import '../../../../core/widgets/app_popup.dart';
import '../../application/game_providers.dart';
import '../../game_localizations.dart';
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
  final _packNameCtrl = TextEditingController();
  int _round = 1;
  QuestionType _type = QuestionType.normal;
  QuestionMediaType _mediaType = QuestionMediaType.none;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_packNameCtrl.text.isEmpty) {
      _packNameCtrl.text = context.l10n.myPackDefault;
    }
  }

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
      appBar: AppBar(title: Text(context.l10n.roomEditorTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(context.l10n.roomIdLabel(widget.roomId)),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('room_editor_theme_field'),
              controller: _themeCtrl,
              decoration: InputDecoration(labelText: context.l10n.themeLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('room_editor_question_field'),
              controller: _textCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.questionLabel,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('room_editor_answer_field'),
              controller: _answerCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.answerForHostLabel,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('room_editor_aliases_field'),
              controller: _aliasesCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.answerAliasesLabel,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('room_editor_media_url_field'),
              controller: _mediaUrlCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.mediaUrlOptionalLabel,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('room_editor_cost_field'),
                    controller: _costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.costLabel,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  key: const ValueKey('room_editor_round_dropdown'),
                  value: _round,
                  items: [
                    DropdownMenuItem(
                      value: 1,
                      child: Text(context.l10n.round1),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(context.l10n.round2),
                    ),
                  ],
                  onChanged: (v) => setState(() => _round = v ?? 1),
                ),
                const SizedBox(width: 8),
                DropdownButton<QuestionType>(
                  key: const ValueKey('room_editor_type_dropdown'),
                  value: _type,
                  items: QuestionType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.localizedLabel(context)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _type = v ?? QuestionType.normal),
                ),
                const SizedBox(width: 8),
                DropdownButton<QuestionMediaType>(
                  key: const ValueKey('room_editor_media_type_dropdown'),
                  value: _mediaType,
                  items: QuestionMediaType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.localizedLabel(context)),
                        ),
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
                    key: const ValueKey('room_editor_add_question_button'),
                    onPressed: () async {
                      final l10n = context.l10n;
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
                      showAppPopup(
                        this.context,
                        message: l10n.questionAdded,
                        type: AppPopupType.success,
                      );
                    },
                    child: Text(context.l10n.addQuestion),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('room_editor_export_json_button'),
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
                        title: context.l10n.exportPackageTitle,
                        jsonText: pretty,
                        readOnly: true,
                      );
                    },
                    child: Text(context.l10n.exportJson),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('room_editor_import_json_button'),
                    onPressed: () => _showImportDialog(context, actions),
                    child: Text(context.l10n.importJson),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: questionsAsync.when(
                loading: () => const Center(child: LoadingPane()),
                error: (error, stackTrace) => Center(
                  child: Text(context.l10n.errorWithDetails(error.toString())),
                ),
                data: (questions) {
                  if (questions.isEmpty) {
                    return Center(child: Text(context.l10n.noQuestions));
                  }
                  return ListView.builder(
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      return ListTile(
                        key: ValueKey(
                          'room_editor_question_tile_${q.id}_${q.type.value}_${q.mediaType.value}',
                        ),
                        title: Text(
                          'R${q.round} | ${q.theme} | ${q.cost} | ${q.type.localizedLabel(context)}',
                        ),
                        subtitle: Text(
                          '${q.text}\n${q.mediaUrl.isEmpty ? '' : '${context.l10n.mediaLabel}: ${q.mediaType.localizedLabel(context)}'}',
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
                    decoration: InputDecoration(
                      labelText: context.l10n.packNameLabel,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  key: const ValueKey('room_editor_save_pack_button'),
                  onPressed: () async {
                    final l10n = context.l10n;
                    final result = await actions.savePack(
                      roomId: widget.roomId,
                      name: _packNameCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    showAppPopup(
                      this.context,
                      message: l10n.packSavedVersion(result.version),
                      type: AppPopupType.success,
                    );
                  },
                  child: Text(context.l10n.savePack),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('room_editor_packs_catalog_button'),
                    onPressed: () => _showPacksDialog(actions),
                    child: Text(context.l10n.packsCatalog),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    key: const ValueKey('room_editor_go_to_room_button'),
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
                    child: Text(context.l10n.goToRoom),
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

  Future<void> _showPacksDialog(GameActionsController actions) async {
    final packs = await actions.listPacks();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.packsCatalog),
          content: SizedBox(
            width: 700,
            child: packs.isEmpty
                ? Text(context.l10n.packsEmpty)
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: packs.length,
                    itemBuilder: (context, index) {
                      final p = packs[index];
                      return ListTile(
                        title: Text('${p.name} v${p.version}'),
                        subtitle: Text(
                          context.l10n.questionsCount(p.questionCount),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await actions.applyPack(
                              roomId: widget.roomId,
                              packId: p.id,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                          child: Text(context.l10n.apply),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.close),
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
          title: Text(context.l10n.importPackJsonTitle),
          content: SizedBox(
            width: 700,
            child: TextField(
              controller: ctrl,
              maxLines: 20,
              decoration: InputDecoration(
                hintText: context.l10n.pasteJsonQuestionsHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final l10n = context.l10n;
                try {
                  final raw = jsonDecode(ctrl.text);
                  final list = raw is List
                      ? raw
                      : (raw is Map<String, dynamic>
                            ? (raw['questions'] as List? ?? const [])
                            : const []);
                  final drafts = <QuestionDraft>[];
                  for (final item in list) {
                    if (item is! Map) continue;
                    final map = Map<String, dynamic>.from(item);
                    drafts.add(
                      QuestionDraft(
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
                  await actions.addQuestions(
                    roomId: widget.roomId,
                    drafts: drafts,
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                } catch (e) {
                  if (!mounted) return;
                  showAppPopup(
                    context,
                    message: l10n.importError(e.toString()),
                    type: AppPopupType.error,
                  );
                }
              },
              child: Text(context.l10n.importAction),
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
              child: Text(context.l10n.close),
            ),
          ],
        );
      },
    );
  }
}
