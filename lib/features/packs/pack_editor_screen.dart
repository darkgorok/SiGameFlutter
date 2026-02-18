import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n.dart';
import '../../core/widgets/app_popup.dart';
import '../game/game_localizations.dart';
import '../game/game_models.dart';
import 'local_pack.dart';
import 'pack_file.dart';

class PackEditorScreen extends StatefulWidget {
  const PackEditorScreen({
    super.key,
    this.initialPack,
    this.startEmpty = false,
  });

  final LocalPackDocument? initialPack;
  final bool startEmpty;

  @override
  State<PackEditorScreen> createState() => _PackEditorScreenState();
}

class _PackEditorScreenState extends State<PackEditorScreen> {
  static const _draftPrefsKey = 'pack_editor_draft_v1';
  static const _draftFileName = 'pack_editor_draft_v1.json';
  static const _maxHistory = 80;
  static const _maxQuestionTextChars = 400;
  static const _maxAnswerChars = 120;
  static const _maxAliasesChars = 240;
  static const _maxPackNameChars = 80;
  static const _maxMediaDataUrlChars = 6 * 1024 * 1024;

  final _packNameCtrl = TextEditingController();
  final _themeCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _aliasesCtrl = TextEditingController();
  final _costCtrl = TextEditingController(text: '100');
  final _mediaUrlCtrl = TextEditingController();

  final List<LocalPackQuestion> _questions = [];
  final List<int> _roundOrder = <int>[];
  final List<String> _themeOrder = [];
  final Map<String, int> _themeRoundHint = <String, int>{};

  int _round = 1;
  int _selectedRound = 1;
  QuestionType _type = QuestionType.normal;
  QuestionMediaType _mediaType = QuestionMediaType.none;
  int? _editingIndex;
  bool _busy = false;
  bool _packNameInitialized = false;
  bool _templateInitialized = false;
  bool _editorVisible = false;
  String? _mediaFileLabel;
  String? _selectedThemeName;
  bool _suppressEditorSync = false;
  bool _draftDirty = false;
  Timer? _editorSyncDebounce;
  Timer? _uiRefreshDebounce;
  Timer? _autosaveDebounce;
  Timer? _validationDebounce;
  Timer? _structureSyncDebounce;
  bool _restoringDraft = false;
  bool _structureDirty = false;
  final Map<int, List<String>> _questionValidationCache = <int, List<String>>{};
  final Set<int> _dirtyQuestionValidation = <int>{};
  bool _fullValidationDirty = true;
  final ValueNotifier<int> _validationRevision = ValueNotifier<int>(0);
  final ValueNotifier<_DraftState> _draftState = ValueNotifier<_DraftState>(
    _DraftState.saved,
  );
  int _questionsRevision = 0;
  int _cachedRoundRevision = -1;
  int _cachedRoundValue = -1;
  Map<String, int> _cachedCountsByTheme = <String, int>{};
  List<String> _cachedThemesForRound = <String>[];

  final List<_EditorSnapshot> _undoStack = <_EditorSnapshot>[];
  final List<_EditorSnapshot> _redoStack = <_EditorSnapshot>[];
  final List<_QuestionPatchAction> _undoPatchStack = <_QuestionPatchAction>[];
  final List<_QuestionPatchAction> _redoPatchStack = <_QuestionPatchAction>[];
  int _historySeq = 0;

  @override
  void initState() {
    super.initState();
    final initialPack = widget.initialPack;
    if (initialPack != null) {
      _packNameCtrl.text = initialPack.name;
      _questions.addAll(initialPack.questions);
      _syncStructureFromQuestions();
      _packNameInitialized = true;
    } else if (widget.startEmpty) {
      _packNameCtrl.text = '';
      _packNameInitialized = true;
    }
    _attachRealtimeListeners();
    if (initialPack == null) {
      _restoreDraftIfAny();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_packNameInitialized && _packNameCtrl.text.trim().isEmpty) {
      _packNameCtrl.text = context.l10n.newPackDefault;
      _packNameInitialized = true;
    }
    if (widget.startEmpty && !_templateInitialized && _questions.isEmpty) {
      _initDefaultTemplate();
      _templateInitialized = true;
    }
  }

  @override
  void dispose() {
    _editorSyncDebounce?.cancel();
    _uiRefreshDebounce?.cancel();
    _autosaveDebounce?.cancel();
    _validationDebounce?.cancel();
    _structureSyncDebounce?.cancel();
    _validationRevision.dispose();
    _draftState.dispose();
    _packNameCtrl.dispose();
    _themeCtrl.dispose();
    _textCtrl.dispose();
    _answerCtrl.dispose();
    _aliasesCtrl.dispose();
    _costCtrl.dispose();
    _mediaUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensureRoundDerivedCache();
    final countsByTheme = _cachedCountsByTheme;
    final themesForRound = _cachedThemesForRound;
    final selectedTheme = _resolveSelectedTheme(themesForRound);
    final editorThemeValue = _resolveEditorThemeValue(
      themesForRound,
      selectedTheme,
    );
    final themeQuestionEntries = selectedTheme == null
        ? const <_ThemeQuestionEntry>[]
        : _entriesForTheme(selectedTheme, round: _selectedRound);
    final packNameInvalid = _packNameCtrl.text.trim().isEmpty;
    final packNameLong = _packNameCtrl.text.length > _maxPackNameChars;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.packEditor)),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _packNameCtrl,
                    decoration: _fieldDecoration(
                      InputDecoration(
                        isDense: true,
                        labelText: context.l10n.packNameLabel,
                      ),
                      invalid: packNameInvalid,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: context.l10n.uploadFile,
                  onPressed: _busy ? null : _importFromFile,
                  icon: const Icon(Icons.upload_file),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: _validationRevision,
                  builder: (context, revision, child) {
                    final issuesCount = _packValidationIssues().length;
                    final tooltip = issuesCount == 0
                        ? context.l10n.saveToFile
                        : '${context.l10n.saveToFile} ($issuesCount)';
                    return IconButton(
                      tooltip: tooltip,
                      onPressed: _busy ? null : _exportToFile,
                      color: issuesCount == 0 ? null : Colors.amber,
                      icon: const Icon(Icons.download),
                    );
                  },
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<_DraftState>(
                  valueListenable: _draftState,
                  builder: (context, state, child) {
                    return Text(
                      _draftStateLabel(state),
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
                IconButton(
                  tooltip: context.l10n.clear,
                  onPressed: _busy ? null : _clearPack,
                  icon: const Icon(Icons.delete_outline),
                ),
                IconButton(
                  tooltip: 'Undo',
                  onPressed: _busy || !_canUndo ? null : _undo,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Redo',
                  onPressed: _busy || !_canRedo ? null : _redo,
                  icon: const Icon(Icons.redo),
                ),
                IconButton(
                  tooltip: 'Preview',
                  onPressed: _showBoardPreview,
                  icon: const Icon(Icons.preview),
                ),
              ],
            ),
            if (packNameLong)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Pack name is long (${_packNameCtrl.text.length}/$_maxPackNameChars)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade700,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 280,
                    child: Column(
                      children: [
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                dense: true,
                                title: Text(
                                  '${context.l10n.roundLabel} (${_roundOrder.length})',
                                ),
                                trailing: Wrap(
                                  spacing: 2,
                                  children: [
                                    IconButton(
                                      tooltip: 'Добавить раунд',
                                      onPressed: _busy ? null : _addRound,
                                      icon: const Icon(Icons.add),
                                    ),
                                    IconButton(
                                      tooltip: 'Удалить раунд',
                                      onPressed:
                                          _busy || _roundOrder.length <= 1
                                          ? null
                                          : _removeSelectedRound,
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              ..._roundOrder.map(
                                (round) => ListTile(
                                  dense: true,
                                  selected: _selectedRound == round,
                                  onTap: _busy
                                      ? null
                                      : () => setState(() {
                                          _selectedRound = round;
                                          _round = round;
                                          _editingIndex = null;
                                          _editorVisible = false;
                                        }),
                                  title: Text(_roundLabel(round)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Card(
                            child: Column(
                              children: [
                                ListTile(
                                  dense: true,
                                  title: Text(
                                    '${context.l10n.themeLabel} (${themesForRound.length})',
                                  ),
                                  trailing: Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        tooltip: 'Дублировать тему',
                                        onPressed:
                                            _busy || selectedTheme == null
                                            ? null
                                            : () => _duplicateTheme(
                                                selectedTheme,
                                                _selectedRound,
                                              ),
                                        icon: const Icon(Icons.copy),
                                      ),
                                      IconButton(
                                        tooltip: context.l10n.addQuestion,
                                        onPressed: _busy ? null : _addTheme,
                                        icon: const Icon(Icons.add),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: themesForRound.isEmpty
                                      ? Center(
                                          child: Text(
                                            context.l10n.noThemeFallback,
                                          ),
                                        )
                                      : ReorderableListView.builder(
                                          buildDefaultDragHandles: false,
                                          itemCount: themesForRound.length,
                                          onReorder: _busy
                                              ? _onDisabledReorder
                                              : (oldIndex, newIndex) =>
                                                    _reorderThemesForRound(
                                                      themesForRound,
                                                      oldIndex,
                                                      newIndex,
                                                    ),
                                          itemBuilder: (context, index) {
                                            final theme = themesForRound[index];
                                            final selected =
                                                selectedTheme == theme;
                                            final count =
                                                countsByTheme[theme] ?? 0;
                                            return ListTile(
                                              key: ValueKey(
                                                'theme-$theme-$index',
                                              ),
                                              dense: true,
                                              selected: selected,
                                              onTap: _busy
                                                  ? null
                                                  : () => setState(
                                                      () => _selectedThemeName =
                                                          theme,
                                                    ),
                                              title: Text(theme),
                                              subtitle: Text(
                                                context.l10n.questionsCount(
                                                  count,
                                                ),
                                              ),
                                              trailing:
                                                  ReorderableDragStartListener(
                                                    index: index,
                                                    child: const Icon(
                                                      Icons.drag_handle,
                                                    ),
                                                  ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedTheme == null
                                    ? context.l10n.noThemeFallback
                                    : '$selectedTheme | ${context.l10n.questionsCount(themeQuestionEntries.length)}',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy || selectedTheme == null
                                  ? null
                                  : _startCreateQuestion,
                              icon: const Icon(Icons.add),
                              label: Text(context.l10n.addQuestion),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Card(
                            child: selectedTheme == null
                                ? Center(
                                    child: Text(context.l10n.noThemeFallback),
                                  )
                                : themeQuestionEntries.isEmpty
                                ? Center(
                                    child: Text(
                                      context.l10n.packHasNoQuestionsYet,
                                    ),
                                  )
                                : ReorderableListView.builder(
                                    buildDefaultDragHandles: false,
                                    itemCount: themeQuestionEntries.length,
                                    onReorder: _busy
                                        ? _onDisabledReorder
                                        : (oldIndex, newIndex) =>
                                              _reorderQuestionsInTheme(
                                                selectedTheme,
                                                oldIndex,
                                                newIndex,
                                              ),
                                    itemBuilder: (context, index) {
                                      final entry = themeQuestionEntries[index];
                                      final q = entry.question;
                                      final summary = q.text.trim().isEmpty
                                          ? context.l10n.questionLabel
                                          : q.text.trim();
                                      final selectedItem =
                                          _editingIndex == entry.globalIndex;
                                      return ListTile(
                                        key: ValueKey(
                                          'q-${entry.globalIndex}-${q.text.hashCode}',
                                        ),
                                        selected: selectedItem,
                                        dense: true,
                                        onTap: _busy
                                            ? null
                                            : () => _editQuestion(
                                                entry.globalIndex,
                                              ),
                                        title: Text('${index + 1}. $summary'),
                                        subtitle: Text(
                                          '${context.l10n.roundLabel} ${q.round} | ${q.cost} | ${q.type.localizedLabel(context)}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _duplicateQuestion(
                                                      entry.globalIndex,
                                                    ),
                                              icon: const Icon(Icons.copy),
                                            ),
                                            IconButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _removeQuestion(
                                                      entry.globalIndex,
                                                    ),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                            ReorderableDragStartListener(
                                              index: index,
                                              child: const Icon(
                                                Icons.drag_handle,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) {
                            return SizeTransition(
                              sizeFactor: animation,
                              axisAlignment: -1,
                              child: child,
                            );
                          },
                          child: !_editorVisible
                              ? const SizedBox.shrink()
                              : Padding(
                                  key: ValueKey<int?>(_editingIndex),
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _buildQuestionEditor(
                                    themesForRound: themesForRound,
                                    editorThemeValue: editorThemeValue,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionEditor({
    required List<String> themesForRound,
    required String? editorThemeValue,
  }) {
    return _QuestionEditorPanel(
      busy: _busy,
      roundOrder: _roundOrder,
      round: _round,
      selectedRound: _selectedRound,
      type: _type,
      mediaType: _mediaType,
      mediaFileLabel: _mediaFileLabel,
      maxQuestionTextChars: _maxQuestionTextChars,
      maxAnswerChars: _maxAnswerChars,
      maxAliasesChars: _maxAliasesChars,
      maxMediaDataUrlChars: _maxMediaDataUrlChars,
      themesForRound: themesForRound,
      editorThemeValue: editorThemeValue,
      roundLabel: _roundLabel,
      fieldDecoration: _fieldDecoration,
      themeCtrl: _themeCtrl,
      textCtrl: _textCtrl,
      answerCtrl: _answerCtrl,
      aliasesCtrl: _aliasesCtrl,
      costCtrl: _costCtrl,
      mediaUrlCtrl: _mediaUrlCtrl,
      onThemeChanged: (value) {
        setState(() {
          _themeCtrl.text = value;
          _selectedThemeName = value;
        });
        _syncQuestionFromEditor(pushHistory: false);
      },
      onRoundChanged: (value) {
        setState(() {
          _round = value;
          _selectedRound = value;
        });
        _syncQuestionFromEditor(pushHistory: false);
      },
      onTypeChanged: (value) {
        setState(() => _type = value);
        _syncQuestionFromEditor(pushHistory: false);
      },
      onPickMedia: _pickMediaForEditor,
      onClearMedia: () {
        setState(() {
          _mediaUrlCtrl.clear();
          _mediaType = QuestionMediaType.none;
          _mediaFileLabel = null;
        });
        _syncQuestionFromEditor(pushHistory: false);
      },
      onCancel: _cancelEdit,
    );
  }

  List<String> _themesForRound(int round) {
    return _themeOrder.where((theme) {
      final hasQuestions = _questions.any(
        (q) => q.theme == theme && q.round == round,
      );
      return hasQuestions || _themeRoundHint[theme] == round;
    }).toList();
  }

  String? _resolveSelectedTheme(List<String> themesForRound) {
    if (themesForRound.isEmpty) {
      _selectedThemeName = null;
      _themeCtrl.clear();
      return null;
    }
    if (_selectedThemeName != null &&
        themesForRound.contains(_selectedThemeName)) {
      return _selectedThemeName;
    }
    final direct = _themeCtrl.text.trim();
    if (direct.isNotEmpty && themesForRound.contains(direct)) {
      _selectedThemeName = direct;
      return direct;
    }
    _selectedThemeName = themesForRound.first;
    _themeCtrl.text = _selectedThemeName!;
    return _selectedThemeName;
  }

  String? _resolveEditorThemeValue(
    List<String> themesForRound,
    String? selectedTheme,
  ) {
    final direct = _themeCtrl.text.trim();
    if (direct.isNotEmpty && themesForRound.contains(direct)) {
      return direct;
    }
    return selectedTheme;
  }

  List<_ThemeQuestionEntry> _entriesForTheme(
    String theme, {
    required int round,
  }) {
    final entries = <_ThemeQuestionEntry>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.theme == theme && q.round == round) {
        entries.add(_ThemeQuestionEntry(globalIndex: i, question: q));
      }
    }
    return entries;
  }

  void _attachRealtimeListeners() {
    _packNameCtrl.addListener(() {
      if (!mounted || _suppressEditorSync) return;
      _draftState.value = _DraftState.dirty;
      _scheduleUiRefresh();
      _markValidationDirtyAll();
      _scheduleValidationRefresh();
      _scheduleAutosave();
    });
    final editorListeners = <TextEditingController>[
      _themeCtrl,
      _textCtrl,
      _answerCtrl,
      _aliasesCtrl,
      _costCtrl,
      _mediaUrlCtrl,
    ];
    for (final ctrl in editorListeners) {
      ctrl.addListener(() {
        if (!mounted || _suppressEditorSync) return;
        _draftState.value = _DraftState.dirty;
        _scheduleEditorSync();
        final idx = _editingIndex;
        if (idx != null) {
          _markValidationDirtyQuestion(idx);
          _scheduleValidationRefresh();
        }
        _scheduleAutosave();
      });
    }
  }

  void _scheduleEditorSync() {
    if (!_editorVisible || _editingIndex == null) {
      return;
    }
    _editorSyncDebounce?.cancel();
    _editorSyncDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || _suppressEditorSync) return;
      _syncQuestionFromEditor(pushHistory: false);
    });
  }

  void _scheduleUiRefresh() {
    _uiRefreshDebounce?.cancel();
    _uiRefreshDebounce = Timer(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _markValidationDirtyQuestion(int index) {
    if (index < 0 || index >= _questions.length) {
      return;
    }
    _dirtyQuestionValidation.add(index);
  }

  void _markValidationDirtyAll() {
    _fullValidationDirty = true;
    _dirtyQuestionValidation.clear();
  }

  void _scheduleValidationRefresh() {
    _validationDebounce?.cancel();
    _validationDebounce = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      _packValidationIssues();
      _validationRevision.value++;
    });
  }

  void _scheduleStructureSync() {
    _structureDirty = true;
    _structureSyncDebounce?.cancel();
    _structureSyncDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || !_structureDirty) return;
      setState(() {
        _syncStructureFromQuestions();
        _structureDirty = false;
      });
      _markQuestionsChanged();
      _markValidationDirtyAll();
      _scheduleValidationRefresh();
    });
  }

  Future<File?> _draftFile() async {
    if (kIsWeb) {
      return null;
    }
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_draftFileName');
  }

  Future<String?> _loadDraftRaw() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_draftPrefsKey);
    }
    final file = await _draftFile();
    if (file == null || !await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  Future<void> _saveDraftRaw(String raw) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftPrefsKey, raw);
      return;
    }
    final file = await _draftFile();
    if (file == null) {
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(raw, flush: true);
  }

  Future<void> _clearDraftRaw() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftPrefsKey);
      return;
    }
    final file = await _draftFile();
    if (file == null || !await file.exists()) {
      return;
    }
    await file.delete();
  }

  Future<void> _restoreDraftIfAny() async {
    _restoringDraft = true;
    try {
      final raw = await _loadDraftRaw();
      if (raw == null || raw.trim().isEmpty) {
        return;
      }
      final map = await compute(_decodePackJsonMap, raw);
      final pack = LocalPackDocument.fromJson(map);
      if (!mounted) return;
      setState(() {
        _packNameCtrl.text = pack.name;
        _questions
          ..clear()
          ..addAll(pack.questions);
        _syncStructureFromQuestions();
      });
      _markValidationDirtyAll();
      _scheduleValidationRefresh();
      _draftState.value = _DraftState.restored;
    } catch (_) {
      // Ignore broken draft.
    } finally {
      _restoringDraft = false;
    }
  }

  void _scheduleAutosave() {
    if (_restoringDraft) return;
    _draftDirty = true;
    _draftState.value = _DraftState.saving;
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 900), () async {
      if (!_draftDirty) {
        return;
      }
      final name = _packNameCtrl.text.trim().isEmpty
          ? 'Draft'
          : _packNameCtrl.text.trim();
      final pack = LocalPackDocument(
        name: name,
        questions: List<LocalPackQuestion>.from(_questions),
      );
      await _saveDraftRaw(jsonEncode(pack.toJson()));
      _draftDirty = false;
      _draftState.value = _DraftState.saved;
    });
  }

  void _markQuestionsChanged() {
    _questionsRevision += 1;
  }

  void _ensureRoundDerivedCache() {
    if (_cachedRoundRevision == _questionsRevision &&
        _cachedRoundValue == _selectedRound) {
      return;
    }
    final counts = <String, int>{};
    for (final q in _questions) {
      if (q.round != _selectedRound) continue;
      counts.update(q.theme, (value) => value + 1, ifAbsent: () => 1);
    }
    final themes = _themeOrder.where((theme) {
      return counts.containsKey(theme) ||
          _themeRoundHint[theme] == _selectedRound;
    }).toList();
    _cachedCountsByTheme = counts;
    _cachedThemesForRound = themes;
    _cachedRoundRevision = _questionsRevision;
    _cachedRoundValue = _selectedRound;
  }

  void _pushSnapshot() {
    _undoStack.add(
      _EditorSnapshot(
        seq: ++_historySeq,
        packName: _packNameCtrl.text,
        questions: List<LocalPackQuestion>.from(_questions),
        roundOrder: List<int>.from(_roundOrder),
        themeOrder: List<String>.from(_themeOrder),
        themeRoundHint: Map<String, int>.from(_themeRoundHint),
        selectedRound: _selectedRound,
        round: _round,
        editorVisible: _editorVisible,
        selectedThemeName: _selectedThemeName,
      ),
    );
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    _redoPatchStack.clear();
  }

  void _undo() {
    if (!_canUndo) return;
    final lastSnapshotSeq = _undoStack.isEmpty ? -1 : _undoStack.last.seq;
    final lastPatchSeq = _undoPatchStack.isEmpty
        ? -1
        : _undoPatchStack.last.seq;
    if (lastPatchSeq > lastSnapshotSeq) {
      final patch = _undoPatchStack.removeLast();
      _applyQuestionPatch(patch.index, patch.before);
      _redoPatchStack.add(patch);
      _scheduleAutosave();
      return;
    }
    final current = _captureSnapshot();
    _redoStack.add(current);
    final snapshot = _undoStack.removeLast();
    _applySnapshot(snapshot);
  }

  void _redo() {
    if (!_canRedo) return;
    final lastSnapshotSeq = _redoStack.isEmpty ? -1 : _redoStack.last.seq;
    final lastPatchSeq = _redoPatchStack.isEmpty
        ? -1
        : _redoPatchStack.last.seq;
    if (lastPatchSeq > lastSnapshotSeq) {
      final patch = _redoPatchStack.removeLast();
      _applyQuestionPatch(patch.index, patch.after);
      _undoPatchStack.add(patch);
      _scheduleAutosave();
      return;
    }
    final current = _captureSnapshot();
    _undoStack.add(current);
    final snapshot = _redoStack.removeLast();
    _applySnapshot(snapshot);
  }

  _EditorSnapshot _captureSnapshot() {
    return _EditorSnapshot(
      seq: ++_historySeq,
      packName: _packNameCtrl.text,
      questions: List<LocalPackQuestion>.from(_questions),
      roundOrder: List<int>.from(_roundOrder),
      themeOrder: List<String>.from(_themeOrder),
      themeRoundHint: Map<String, int>.from(_themeRoundHint),
      selectedRound: _selectedRound,
      round: _round,
      editorVisible: _editorVisible,
      selectedThemeName: _selectedThemeName,
    );
  }

  bool get _canUndo => _undoStack.isNotEmpty || _undoPatchStack.isNotEmpty;
  bool get _canRedo => _redoStack.isNotEmpty || _redoPatchStack.isNotEmpty;

  void _recordQuestionPatch(
    int index,
    LocalPackQuestion before,
    LocalPackQuestion after,
  ) {
    _redoStack.clear();
    _redoPatchStack.clear();
    final merged =
        _undoPatchStack.isNotEmpty &&
        _undoPatchStack.last.index == index &&
        DateTime.now().difference(_undoPatchStack.last.timestamp) <
            const Duration(milliseconds: 900);
    if (merged) {
      final last = _undoPatchStack.removeLast();
      _undoPatchStack.add(
        _QuestionPatchAction(
          seq: ++_historySeq,
          index: index,
          before: last.before,
          after: after,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }
    _undoPatchStack.add(
      _QuestionPatchAction(
        seq: ++_historySeq,
        index: index,
        before: before,
        after: after,
        timestamp: DateTime.now(),
      ),
    );
    if (_undoPatchStack.length > _maxHistory * 2) {
      _undoPatchStack.removeAt(0);
    }
  }

  void _applyQuestionPatch(int index, LocalPackQuestion patchQuestion) {
    if (index < 0 || index >= _questions.length) {
      return;
    }
    setState(() {
      _questions[index] = patchQuestion;
      _syncStructureFromQuestions();
      if (_editingIndex == index) {
        _setEditorFromQuestion(patchQuestion);
      }
    });
    _markQuestionsChanged();
    _markValidationDirtyQuestion(index);
    _scheduleValidationRefresh();
  }

  void _applySnapshot(_EditorSnapshot snapshot) {
    setState(() {
      _packNameCtrl.text = snapshot.packName;
      _questions
        ..clear()
        ..addAll(snapshot.questions);
      _roundOrder
        ..clear()
        ..addAll(snapshot.roundOrder);
      _themeOrder
        ..clear()
        ..addAll(snapshot.themeOrder);
      _themeRoundHint
        ..clear()
        ..addAll(snapshot.themeRoundHint);
      _selectedRound = snapshot.selectedRound;
      _round = snapshot.round;
      _editorVisible = snapshot.editorVisible;
      _selectedThemeName = snapshot.selectedThemeName;
    });
    _markQuestionsChanged();
    _markValidationDirtyAll();
    _scheduleValidationRefresh();
    _scheduleAutosave();
  }

  InputDecoration _fieldDecoration(
    InputDecoration base, {
    required bool invalid,
  }) {
    if (!invalid) {
      return base;
    }
    const redBorder = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red, width: 1.4),
    );
    return base.copyWith(
      border: redBorder,
      enabledBorder: redBorder,
      focusedBorder: redBorder,
    );
  }

  List<String> _packValidationIssues() {
    if (_fullValidationDirty) {
      _questionValidationCache.clear();
      for (var i = 0; i < _questions.length; i++) {
        _questionValidationCache[i] = _validateQuestionAt(i);
      }
      _fullValidationDirty = false;
      _dirtyQuestionValidation.clear();
    } else if (_dirtyQuestionValidation.isNotEmpty) {
      final validIndexes =
          _dirtyQuestionValidation
              .where((i) => i >= 0 && i < _questions.length)
              .toList()
            ..sort();
      for (final i in validIndexes) {
        _questionValidationCache[i] = _validateQuestionAt(i);
      }
      _dirtyQuestionValidation.clear();
    }

    final issues = <String>[];
    if (_packNameCtrl.text.trim().isEmpty) {
      issues.add('Pack name is required');
    }
    if (_questions.isEmpty) {
      issues.add('Pack must contain at least one question');
      return issues;
    }

    final keys = _questionValidationCache.keys.toList()..sort();
    for (final i in keys) {
      issues.addAll(_questionValidationCache[i] ?? const <String>[]);
      if (issues.length >= 20) {
        issues
          ..removeRange(20, issues.length)
          ..add('... and more issues');
        break;
      }
    }
    return issues;
  }

  List<String> _validateQuestionAt(int index) {
    final q = _questions[index];
    final idx = index + 1;
    final issues = <String>[];
    if (q.theme.trim().isEmpty) {
      issues.add('Q$idx: empty theme');
    }
    if (q.text.trim().isEmpty) {
      issues.add('Q$idx: empty question text');
    }
    if (q.answer.trim().isEmpty) {
      issues.add('Q$idx: empty answer');
    }
    if (q.cost <= 0) {
      issues.add('Q$idx: cost must be > 0');
    }
    if (q.round <= 0) {
      issues.add('Q$idx: invalid round');
    }
    if (q.type == QuestionType.closestNumber &&
        num.tryParse(q.answer.trim()) == null) {
      issues.add('Q$idx: closest number answer must be numeric');
    }
    return issues;
  }

  void _showBoardPreview() {
    final grouped = <int, Map<String, List<LocalPackQuestion>>>{};
    for (final q in _questions) {
      grouped.putIfAbsent(q.round, () => <String, List<LocalPackQuestion>>{});
      grouped[q.round]!.putIfAbsent(q.theme, () => <LocalPackQuestion>[]);
      grouped[q.round]![q.theme]!.add(q);
    }
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Game Board Preview'),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    (_roundOrder.isEmpty
                            ? (grouped.keys.toList()..sort())
                            : List<int>.from(_roundOrder))
                        .map((round) {
                          final themes =
                              grouped[round] ??
                              const <String, List<LocalPackQuestion>>{};
                          final themeNames = themes.keys.toList();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Round $round'),
                                const SizedBox(height: 6),
                                if (themeNames.isEmpty) const Text('No themes'),
                                ...themeNames.map((theme) {
                                  final list = List<LocalPackQuestion>.from(
                                    themes[theme]!,
                                  )..sort((a, b) => a.cost.compareTo(b.cost));
                                  final costs = list
                                      .map((q) => q.cost)
                                      .join(', ');
                                  return Text('$theme: $costs');
                                }),
                              ],
                            ),
                          );
                        })
                        .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(this.context.l10n.close),
            ),
          ],
        );
      },
    );
  }

  void _initDefaultTemplate() {
    final prefix = context.l10n.themeFallback;
    _questions.clear();
    for (var themeIdx = 1; themeIdx <= 3; themeIdx++) {
      final theme = '$prefix $themeIdx';
      for (var qIdx = 0; qIdx < 5; qIdx++) {
        _questions.add(
          LocalPackQuestion(
            theme: theme,
            text: '',
            answer: '',
            cost: 100,
            round: 1,
            type: QuestionType.normal,
            mediaUrl: '',
            mediaType: QuestionMediaType.none,
            aliases: const [],
          ),
        );
      }
    }
    _syncStructureFromQuestions();
    _markQuestionsChanged();
    _themeCtrl.text = _themeOrder.first;
    _selectedThemeName = _themeOrder.first;
  }

  void _syncStructureFromQuestions() {
    final roundsFromQuestions =
        _questions.map((q) => q.round).where((r) => r > 0).toSet().toList()
          ..sort();
    final mergedRoundOrder = <int>[
      ..._roundOrder.where((r) => r > 0),
      ...roundsFromQuestions.where((r) => !_roundOrder.contains(r)),
    ];
    if (mergedRoundOrder.isEmpty) {
      mergedRoundOrder.add(1);
    }
    _roundOrder
      ..clear()
      ..addAll(mergedRoundOrder);
    if (!_roundOrder.contains(_selectedRound)) {
      _selectedRound = _roundOrder.first;
    }

    _themeRoundHint.clear();
    _themeOrder.clear();
    for (final q in _questions) {
      if (q.theme.trim().isEmpty) continue;
      if (!_themeOrder.contains(q.theme)) {
        _themeOrder.add(q.theme);
      }
      _themeRoundHint.putIfAbsent(q.theme, () => q.round);
    }
    if (_themeOrder.isEmpty) {
      _selectedThemeName = null;
      _themeCtrl.clear();
      return;
    }
    if (_selectedThemeName != null &&
        _themeOrder.contains(_selectedThemeName)) {
      _themeCtrl.text = _selectedThemeName!;
      return;
    }
    _selectedThemeName = _themeOrder.first;
    _themeCtrl.text = _selectedThemeName!;
  }

  String _roundLabel(int round) {
    return '${context.l10n.roundLabel} $round';
  }

  void _addRound() {
    _pushSnapshot();
    setState(() {
      final next = (_roundOrder.isEmpty ? 0 : _roundOrder.last) + 1;
      _roundOrder.add(next);
      _selectedRound = next;
      _round = next;
      _selectedThemeName = null;
      _themeCtrl.clear();
      _editorVisible = false;
      _editingIndex = null;
      _clearQuestionInputs();
    });
    _markQuestionsChanged();
    _markValidationDirtyAll();
    _scheduleValidationRefresh();
    _scheduleAutosave();
  }

  void _removeSelectedRound() {
    if (_roundOrder.length <= 1) {
      return;
    }
    final roundToRemove = _selectedRound;
    _pushSnapshot();
    setState(() {
      _questions.removeWhere((q) => q.round == roundToRemove);
      _roundOrder.remove(roundToRemove);
      final nextRound = _roundOrder.first;
      _selectedRound = nextRound;
      _round = nextRound;
      _editingIndex = null;
      _editorVisible = false;
      _clearQuestionInputs();
      _syncStructureFromQuestions();
    });
    _markQuestionsChanged();
    _markValidationDirtyAll();
    _scheduleValidationRefresh();
    _scheduleAutosave();
  }

  void _addTheme() {
    var idx = _themeOrder.length + 1;
    var candidate = '${context.l10n.themeFallback} $idx';
    while (_themeOrder.contains(candidate)) {
      idx += 1;
      candidate = '${context.l10n.themeFallback} $idx';
    }
    _pushSnapshot();
    setState(() {
      _themeOrder.add(candidate);
      _themeRoundHint[candidate] = _selectedRound;
      _selectedThemeName = candidate;
      _themeCtrl.text = candidate;
    });
    _markQuestionsChanged();
    _markValidationDirtyAll();
    _scheduleValidationRefresh();
    _scheduleAutosave();
  }

  void _startCreateQuestion() {
    final selectedTheme = _resolveSelectedTheme(
      _themesForRound(_selectedRound),
    );
    if (selectedTheme == null) {
      return;
    }
    _pushSnapshot();
    setState(() {
      final question = LocalPackQuestion(
        theme: selectedTheme,
        text: '',
        answer: '',
        cost: 100,
        round: _selectedRound,
        type: QuestionType.normal,
        mediaUrl: '',
        mediaType: QuestionMediaType.none,
        aliases: const [],
      );
      _questions.add(question);
      _editingIndex = _questions.length - 1;
      _editorVisible = true;
      _setEditorFromQuestion(question);
      _syncStructureFromQuestions();
    });
    _markQuestionsChanged();
    _markValidationDirtyAll();
    _scheduleValidationRefresh();
    _scheduleAutosave();
  }

  void _syncQuestionFromEditor({required bool pushHistory}) {
    final index = _editingIndex;
    if (index == null || index < 0 || index >= _questions.length) {
      return;
    }
    final previous = _questions[index];
    final selectedTheme = _resolveSelectedTheme(
      _themesForRound(_selectedRound),
    );
    final theme = _themeCtrl.text.trim().isEmpty
        ? (selectedTheme ?? '')
        : _themeCtrl.text.trim();
    if (theme.isEmpty) {
      return;
    }

    final question = LocalPackQuestion(
      theme: theme,
      text: _textCtrl.text.trim(),
      answer: _answerCtrl.text.trim(),
      cost: int.tryParse(_costCtrl.text.trim()) ?? 100,
      round: _round,
      type: _type,
      mediaUrl: _mediaType == QuestionMediaType.none
          ? ''
          : _mediaUrlCtrl.text.trim(),
      mediaType: _mediaType == QuestionMediaType.none
          ? QuestionMediaType.none
          : _mediaType,
      aliases: _aliasesCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(),
    );

    if (pushHistory) {
      _pushSnapshot();
    } else if (_questionChanged(previous, question)) {
      _recordQuestionPatch(index, previous, question);
    }
    if (!_questionChanged(previous, question)) {
      return;
    }
    _questions[index] = question;
    _markQuestionsChanged();
    _markValidationDirtyQuestion(index);
    _scheduleValidationRefresh();

    final structureChanged =
        previous.theme != question.theme || previous.round != question.round;
    if (structureChanged) {
      setState(() {
        if (!_themeOrder.contains(theme)) {
          _themeOrder.add(theme);
        }
        _themeRoundHint[theme] = question.round;
        _selectedThemeName = theme;
        _selectedRound = question.round;
      });
      _scheduleStructureSync();
    }
    _scheduleAutosave();
  }

  bool _questionChanged(LocalPackQuestion previous, LocalPackQuestion current) {
    if (identical(previous, current)) {
      return false;
    }
    return previous.theme != current.theme ||
        previous.text != current.text ||
        previous.answer != current.answer ||
        previous.cost != current.cost ||
        previous.round != current.round ||
        previous.type != current.type ||
        previous.mediaUrl != current.mediaUrl ||
        previous.mediaType != current.mediaType ||
        !listEquals(previous.aliases, current.aliases);
  }

  void _setEditorFromQuestion(LocalPackQuestion q) {
    _suppressEditorSync = true;
    _themeCtrl.text = q.theme;
    _textCtrl.text = q.text;
    _answerCtrl.text = q.answer;
    _aliasesCtrl.text = q.aliases.join(', ');
    _costCtrl.text = q.cost.toString();
    _round = q.round;
    _type = q.type;
    _mediaUrlCtrl.text = q.mediaUrl;
    _mediaType = q.mediaType;
    _suppressEditorSync = false;
  }

  void _editQuestion(int index) {
    final q = _questions[index];
    setState(() {
      _editingIndex = index;
      _setEditorFromQuestion(q);
      final idx = _themeOrder.indexOf(q.theme);
      if (idx >= 0) {
        _selectedThemeName = _themeOrder[idx];
      }
      _selectedRound = q.round;
      _editorVisible = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _editorVisible = false;
      _clearQuestionInputs();
    });
  }

  void _removeQuestion(int index) {
    _pushSnapshot();
    setState(() {
      _questions.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
        _editorVisible = false;
        _clearQuestionInputs();
      } else if (_editingIndex != null && _editingIndex! > index) {
        _editingIndex = _editingIndex! - 1;
      }
      _syncStructureFromQuestions();
    });
    _markQuestionsChanged();
    _markValidationDirtyAll();
    _scheduleValidationRefresh();
    _scheduleAutosave();
  }

  void _clearPack() {
    _pushSnapshot();
    setState(() {
      _questions.clear();
      _roundOrder.clear();
      _themeOrder.clear();
      _themeRoundHint.clear();
      _editingIndex = null;
      _editorVisible = false;
      _selectedRound = 1;
      _selectedThemeName = null;
      _clearQuestionInputs();
    });
    _markQuestionsChanged();
    _markValidationDirtyAll();
    _scheduleValidationRefresh();
    _scheduleAutosave();
  }

  void _reorderThemesForRound(
    List<String> roundThemes,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final reordered = List<String>.from(roundThemes);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    _pushSnapshot();
    setState(() {
      var cursor = 0;
      for (var i = 0; i < _themeOrder.length; i++) {
        if (roundThemes.contains(_themeOrder[i])) {
          _themeOrder[i] = reordered[cursor];
          cursor += 1;
        }
      }
      _selectedThemeName = moved;
      _rebuildQuestionsFromThemeOrder();
      _editingIndex = null;
    });
    _markQuestionsChanged();
    _markValidationDirtyAll();
    _scheduleValidationRefresh();
    _scheduleAutosave();
  }

  void _reorderQuestionsInTheme(String theme, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    _pushSnapshot();
    setState(() {
      final questions = _questions
          .where((q) => q.theme == theme && q.round == _selectedRound)
          .toList();
      if (questions.isEmpty) {
        return;
      }
      final moved = questions.removeAt(oldIndex);
      questions.insert(newIndex, moved);

      var themeCursor = 0;
      for (var i = 0; i < _questions.length; i++) {
        if (_questions[i].theme == theme &&
            _questions[i].round == _selectedRound) {
          _questions[i] = questions[themeCursor];
          themeCursor += 1;
        }
      }
      _editingIndex = null;
      _editorVisible = false;
    });
    _markQuestionsChanged();
    _markValidationDirtyAll();
    _scheduleValidationRefresh();
    _scheduleAutosave();
  }

  void _rebuildQuestionsFromThemeOrder() {
    final buckets = <String, List<LocalPackQuestion>>{};
    for (final theme in _themeOrder) {
      buckets[theme] = <LocalPackQuestion>[];
    }
    for (final q in _questions) {
      buckets.putIfAbsent(q.theme, () => <LocalPackQuestion>[]);
      buckets[q.theme]!.add(q);
      if (!_themeOrder.contains(q.theme)) {
        _themeOrder.add(q.theme);
      }
    }
    final rebuilt = <LocalPackQuestion>[];
    for (final theme in _themeOrder) {
      rebuilt.addAll(buckets[theme] ?? const <LocalPackQuestion>[]);
    }
    _questions
      ..clear()
      ..addAll(rebuilt);
  }

  void _duplicateQuestion(int globalIndex) {
    if (globalIndex < 0 || globalIndex >= _questions.length) {
      return;
    }
    _pushSnapshot();
    setState(() {
      final source = _questions[globalIndex];
      final copy = LocalPackQuestion(
        theme: source.theme,
        text: source.text,
        answer: source.answer,
        cost: source.cost,
        round: source.round,
        type: source.type,
        mediaUrl: source.mediaUrl,
        mediaType: source.mediaType,
        aliases: List<String>.from(source.aliases),
      );
      _questions.insert(globalIndex + 1, copy);
    });
    _markQuestionsChanged();
    _markValidationDirtyAll();
    _scheduleValidationRefresh();
    _scheduleAutosave();
  }

  void _duplicateTheme(String sourceTheme, int round) {
    final sourceQuestions = _questions
        .where((q) => q.theme == sourceTheme && q.round == round)
        .toList();
    if (sourceQuestions.isEmpty) {
      return;
    }
    var newTheme = '$sourceTheme (copy)';
    var suffix = 2;
    final existingNames = _themeOrder.toSet();
    while (existingNames.contains(newTheme)) {
      newTheme = '$sourceTheme (copy $suffix)';
      suffix += 1;
    }

    _pushSnapshot();
    setState(() {
      final insertAt = _themeOrder.contains(sourceTheme)
          ? _themeOrder.indexOf(sourceTheme) + 1
          : _themeOrder.length;
      _themeOrder.insert(insertAt, newTheme);
      _themeRoundHint[newTheme] = round;
      final clones = sourceQuestions
          .map(
            (q) => LocalPackQuestion(
              theme: newTheme,
              text: q.text,
              answer: q.answer,
              cost: q.cost,
              round: q.round,
              type: q.type,
              mediaUrl: q.mediaUrl,
              mediaType: q.mediaType,
              aliases: List<String>.from(q.aliases),
            ),
          )
          .toList();
      _questions.addAll(clones);
      _selectedThemeName = newTheme;
    });
    _markQuestionsChanged();
    _markValidationDirtyAll();
    _scheduleValidationRefresh();
    _scheduleAutosave();
  }

  void _onDisabledReorder(int oldIndex, int newIndex) {}

  Future<void> _importFromFile() async {
    setState(() => _busy = true);
    try {
      final jsonText = await pickPackJsonText();
      if (jsonText == null || jsonText.trim().isEmpty) {
        return;
      }
      final raw = await compute(_decodePackJsonMap, jsonText);
      final pack = LocalPackDocument.fromJson(raw);
      final dryRunIssues = _validateImportedPack(pack);
      if (dryRunIssues.isNotEmpty) {
        final allowImport = await _confirmImportWithIssues(dryRunIssues);
        if (!allowImport) {
          return;
        }
      }
      if (!mounted) return;
      _pushSnapshot();
      setState(() {
        _packNameCtrl.text = pack.name;
        _questions
          ..clear()
          ..addAll(pack.questions);
        _editingIndex = null;
        _editorVisible = false;
        _clearQuestionInputs();
        _syncStructureFromQuestions();
      });
      _markQuestionsChanged();
      _scheduleAutosave();
      _draftState.value = _DraftState.saved;
      showAppPopup(
        context,
        message: context.l10n.questionsLoaded(pack.questions.length),
        type: AppPopupType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppPopup(
        context,
        message: context.l10n.importError(e.toString()),
        type: AppPopupType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportToFile() async {
    final issues = _packValidationIssues();
    if (issues.isNotEmpty) {
      showAppPopup(
        context,
        message: 'Cannot save pack:\n${issues.join('\n')}',
        type: AppPopupType.error,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final pack = _buildNormalizedPackForExport(
        LocalPackDocument(
          name: _packNameCtrl.text.trim().isEmpty
              ? context.l10n.newPackDefault
              : _packNameCtrl.text.trim(),
          questions: List<LocalPackQuestion>.from(_questions),
        ),
      );
      final jsonText = await compute(_encodePrettyJsonMap, pack.toJson());
      final safeName = pack.name
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(' ', '_');
      final ok = await savePackJsonText(
        suggestedFileName: '${safeName.isEmpty ? 'pack' : safeName}.blitz',
        content: jsonText,
      );
      if (!mounted) return;
      await _clearDraftRaw();
      if (!mounted) return;
      _draftState.value = _DraftState.saved;
      showAppPopup(
        context,
        message: ok ? context.l10n.fileSaved : context.l10n.saveCanceled,
        type: ok ? AppPopupType.success : AppPopupType.info,
      );
    } catch (e) {
      if (!mounted) return;
      showAppPopup(
        context,
        message: context.l10n.saveError(e.toString()),
        type: AppPopupType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _clearQuestionInputs() {
    _textCtrl.clear();
    _answerCtrl.clear();
    _aliasesCtrl.clear();
    _costCtrl.text = '100';
    _mediaUrlCtrl.clear();
    _round = _selectedRound;
    _type = QuestionType.normal;
    _mediaType = QuestionMediaType.none;
    _mediaFileLabel = null;
  }

  Future<void> _pickMediaForEditor() async {
    try {
      final picked = await pickQuestionMediaFile();
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _mediaUrlCtrl.text = picked.dataUrl;
        _mediaType = picked.mediaType;
        _mediaFileLabel = picked.fileName;
      });
      _syncQuestionFromEditor(pushHistory: false);
    } catch (e) {
      if (!mounted) return;
      showAppPopup(
        context,
        message: 'Failed to load media: $e',
        type: AppPopupType.error,
      );
    }
  }

  String _draftStateLabel(_DraftState state) {
    switch (state) {
      case _DraftState.saved:
        return 'Saved';
      case _DraftState.saving:
        return 'Saving...';
      case _DraftState.dirty:
        return 'Unsaved';
      case _DraftState.restored:
        return 'Draft restored';
    }
  }

  List<String> _validateImportedPack(LocalPackDocument pack) {
    final issues = <String>[];
    if (pack.name.trim().isEmpty) {
      issues.add('Pack name is empty');
    }
    if (pack.questions.isEmpty) {
      issues.add('Pack has no questions');
      return issues;
    }
    for (var i = 0; i < pack.questions.length && issues.length < 15; i++) {
      final q = pack.questions[i];
      final idx = i + 1;
      if (q.theme.trim().isEmpty) issues.add('Q$idx: empty theme');
      if (q.text.trim().isEmpty) issues.add('Q$idx: empty question text');
      if (q.answer.trim().isEmpty) issues.add('Q$idx: empty answer');
      if (q.cost <= 0) issues.add('Q$idx: invalid cost');
      if (q.round <= 0) issues.add('Q$idx: invalid round');
    }
    return issues;
  }

  Future<bool> _confirmImportWithIssues(List<String> issues) async {
    if (!mounted) return false;
    final details = issues.take(8).join('\n');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import check'),
          content: Text('File has issues:\n$details\n\nImport anyway?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(this.context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  LocalPackDocument _buildNormalizedPackForExport(LocalPackDocument source) {
    final normalizedQuestions = source.questions.map((q) {
      final aliases = q.aliases
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      return LocalPackQuestion(
        theme: q.theme.trim(),
        text: q.text.trim(),
        answer: q.answer.trim(),
        cost: q.cost,
        round: q.round,
        type: q.type,
        mediaUrl: q.mediaUrl.trim(),
        mediaType: q.mediaType,
        aliases: aliases,
      );
    }).toList();
    return LocalPackDocument(
      name: source.name.trim(),
      questions: normalizedQuestions,
    );
  }
}

Map<String, dynamic> _decodePackJsonMap(String text) {
  final raw = jsonDecode(text);
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  throw const FormatException('Invalid pack JSON root');
}

String _encodePrettyJsonMap(Map<String, dynamic> data) {
  return const JsonEncoder.withIndent('  ').convert(data);
}

enum _DraftState { saved, saving, dirty, restored }

class _ThemeQuestionEntry {
  const _ThemeQuestionEntry({
    required this.globalIndex,
    required this.question,
  });

  final int globalIndex;
  final LocalPackQuestion question;
}

class _QuestionEditorPanel extends StatefulWidget {
  const _QuestionEditorPanel({
    required this.busy,
    required this.roundOrder,
    required this.round,
    required this.selectedRound,
    required this.type,
    required this.mediaType,
    required this.mediaFileLabel,
    required this.maxQuestionTextChars,
    required this.maxAnswerChars,
    required this.maxAliasesChars,
    required this.maxMediaDataUrlChars,
    required this.themesForRound,
    required this.editorThemeValue,
    required this.roundLabel,
    required this.fieldDecoration,
    required this.themeCtrl,
    required this.textCtrl,
    required this.answerCtrl,
    required this.aliasesCtrl,
    required this.costCtrl,
    required this.mediaUrlCtrl,
    required this.onThemeChanged,
    required this.onRoundChanged,
    required this.onTypeChanged,
    required this.onPickMedia,
    required this.onClearMedia,
    required this.onCancel,
  });

  final bool busy;
  final List<int> roundOrder;
  final int round;
  final int selectedRound;
  final QuestionType type;
  final QuestionMediaType mediaType;
  final String? mediaFileLabel;
  final int maxQuestionTextChars;
  final int maxAnswerChars;
  final int maxAliasesChars;
  final int maxMediaDataUrlChars;
  final List<String> themesForRound;
  final String? editorThemeValue;
  final String Function(int round) roundLabel;
  final InputDecoration Function(InputDecoration base, {required bool invalid})
  fieldDecoration;
  final TextEditingController themeCtrl;
  final TextEditingController textCtrl;
  final TextEditingController answerCtrl;
  final TextEditingController aliasesCtrl;
  final TextEditingController costCtrl;
  final TextEditingController mediaUrlCtrl;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<int> onRoundChanged;
  final ValueChanged<QuestionType> onTypeChanged;
  final Future<void> Function() onPickMedia;
  final VoidCallback onClearMedia;
  final VoidCallback onCancel;

  @override
  State<_QuestionEditorPanel> createState() => _QuestionEditorPanelState();
}

class _QuestionEditorPanelState extends State<_QuestionEditorPanel> {
  @override
  void initState() {
    super.initState();
    for (final ctrl in _allControllers) {
      ctrl.addListener(_onControllerChanged);
    }
  }

  @override
  void didUpdateWidget(covariant _QuestionEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeCtrl != widget.themeCtrl) {
      oldWidget.themeCtrl.removeListener(_onControllerChanged);
      widget.themeCtrl.addListener(_onControllerChanged);
    }
    if (oldWidget.textCtrl != widget.textCtrl) {
      oldWidget.textCtrl.removeListener(_onControllerChanged);
      widget.textCtrl.addListener(_onControllerChanged);
    }
    if (oldWidget.answerCtrl != widget.answerCtrl) {
      oldWidget.answerCtrl.removeListener(_onControllerChanged);
      widget.answerCtrl.addListener(_onControllerChanged);
    }
    if (oldWidget.aliasesCtrl != widget.aliasesCtrl) {
      oldWidget.aliasesCtrl.removeListener(_onControllerChanged);
      widget.aliasesCtrl.addListener(_onControllerChanged);
    }
    if (oldWidget.costCtrl != widget.costCtrl) {
      oldWidget.costCtrl.removeListener(_onControllerChanged);
      widget.costCtrl.addListener(_onControllerChanged);
    }
    if (oldWidget.mediaUrlCtrl != widget.mediaUrlCtrl) {
      oldWidget.mediaUrlCtrl.removeListener(_onControllerChanged);
      widget.mediaUrlCtrl.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    for (final ctrl in _allControllers) {
      ctrl.removeListener(_onControllerChanged);
    }
    super.dispose();
  }

  List<TextEditingController> get _allControllers => <TextEditingController>[
    widget.themeCtrl,
    widget.textCtrl,
    widget.answerCtrl,
    widget.aliasesCtrl,
    widget.costCtrl,
    widget.mediaUrlCtrl,
  ];

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeInvalid =
        widget.editorThemeValue == null ||
        widget.editorThemeValue!.trim().isEmpty;
    final costValue = int.tryParse(widget.costCtrl.text.trim());
    final costInvalid = costValue == null || costValue <= 0;
    final questionTextInvalid = widget.textCtrl.text.trim().isEmpty;
    final answerTextInvalid = widget.answerCtrl.text.trim().isEmpty;
    final answerNumericInvalid =
        widget.type == QuestionType.closestNumber &&
        num.tryParse(widget.answerCtrl.text.trim()) == null;
    final answerInvalid = answerTextInvalid || answerNumericInvalid;
    final softWarnings = <String>[
      if (widget.textCtrl.text.length > widget.maxQuestionTextChars)
        'Question text is long (${widget.textCtrl.text.length}/${widget.maxQuestionTextChars})',
      if (widget.answerCtrl.text.length > widget.maxAnswerChars)
        'Answer is long (${widget.answerCtrl.text.length}/${widget.maxAnswerChars})',
      if (widget.aliasesCtrl.text.length > widget.maxAliasesChars)
        'Aliases text is long (${widget.aliasesCtrl.text.length}/${widget.maxAliasesChars})',
      if (widget.mediaUrlCtrl.text.length > widget.maxMediaDataUrlChars)
        'Attached media is large (${(widget.mediaUrlCtrl.text.length / (1024 * 1024)).toStringAsFixed(1)} MB)',
    ];
    final currentRound = widget.roundOrder.contains(widget.round)
        ? widget.round
        : (widget.roundOrder.isEmpty
              ? widget.selectedRound
              : widget.roundOrder.first);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: widget.editorThemeValue,
                    decoration: widget.fieldDecoration(
                      InputDecoration(
                        isDense: true,
                        labelText: context.l10n.themeLabel,
                      ),
                      invalid: themeInvalid,
                    ),
                    items: widget.themesForRound
                        .map(
                          (theme) => DropdownMenuItem<String>(
                            value: theme,
                            child: Text(theme),
                          ),
                        )
                        .toList(),
                    onChanged: widget.busy
                        ? null
                        : (value) {
                            if (value == null) return;
                            widget.onThemeChanged(value);
                          },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 85,
                  child: TextField(
                    controller: widget.costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: widget.fieldDecoration(
                      InputDecoration(
                        isDense: true,
                        labelText: context.l10n.costLabel,
                      ),
                      invalid: costInvalid,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: currentRound,
                  items: widget.roundOrder
                      .map(
                        (round) => DropdownMenuItem(
                          value: round,
                          child: Text(widget.roundLabel(round)),
                        ),
                      )
                      .toList(),
                  onChanged: widget.busy
                      ? null
                      : (v) {
                          if (v == null) return;
                          widget.onRoundChanged(v);
                        },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.textCtrl,
              maxLines: 2,
              decoration: widget.fieldDecoration(
                InputDecoration(
                  isDense: true,
                  labelText: context.l10n.questionLabel,
                ),
                invalid: questionTextInvalid,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.answerCtrl,
              decoration: widget.fieldDecoration(
                InputDecoration(
                  isDense: true,
                  labelText: context.l10n.answerForHostLabel,
                ),
                invalid: answerInvalid,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<QuestionType>(
                    initialValue: widget.type,
                    decoration: const InputDecoration(isDense: true),
                    items: QuestionType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.localizedLabel(context)),
                          ),
                        )
                        .toList(),
                    onChanged: widget.busy
                        ? null
                        : (v) => widget.onTypeChanged(v ?? QuestionType.normal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.aliasesCtrl,
              decoration: InputDecoration(
                isDense: true,
                labelText: context.l10n.answerAliasesLabel,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.busy ? null : widget.onPickMedia,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload media'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: widget.busy ? null : widget.onClearMedia,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: _buildMediaPreview(context),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  onPressed: widget.busy ? null : widget.onCancel,
                  child: Text(context.l10n.cancel),
                ),
              ],
            ),
            if (softWarnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  softWarnings.join('\n'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.amber.shade700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(BuildContext context) {
    if (widget.mediaUrlCtrl.text.trim().isEmpty ||
        widget.mediaType == QuestionMediaType.none) {
      return Text(
        'No media selected',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final label =
        widget.mediaFileLabel ?? widget.mediaType.localizedLabel(context);
    final isImage = widget.mediaType == QuestionMediaType.image;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${context.l10n.mediaLabel}: ${widget.mediaType.localizedLabel(context)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          if (isImage && _isDataImage(widget.mediaUrlCtrl.text.trim())) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.mediaUrlCtrl.text.trim(),
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Text(
                  'Image preview unavailable',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isDataImage(String url) {
    return url.startsWith('data:image/');
  }
}

class _EditorSnapshot {
  const _EditorSnapshot({
    required this.seq,
    required this.packName,
    required this.questions,
    required this.roundOrder,
    required this.themeOrder,
    required this.themeRoundHint,
    required this.selectedRound,
    required this.round,
    required this.editorVisible,
    required this.selectedThemeName,
  });

  final int seq;
  final String packName;
  final List<LocalPackQuestion> questions;
  final List<int> roundOrder;
  final List<String> themeOrder;
  final Map<String, int> themeRoundHint;
  final int selectedRound;
  final int round;
  final bool editorVisible;
  final String? selectedThemeName;
}

class _QuestionPatchAction {
  const _QuestionPatchAction({
    required this.seq,
    required this.index,
    required this.before,
    required this.after,
    required this.timestamp,
  });

  final int seq;
  final int index;
  final LocalPackQuestion before;
  final LocalPackQuestion after;
  final DateTime timestamp;
}
