import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/presentation/loading_screen.dart';
import '../../core/hotkeys.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/widgets/app_popup.dart';
import '../../core/widgets/language_switcher.dart';
import '../profile/avatar_picker.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameCtrl = TextEditingController();

  Uint8List? _avatarBytes;
  String _avatarUrl = '';
  double _volume = 1.0;
  bool _profileLoaded = false;
  bool _saving = false;
  bool _avatarHovered = false;
  bool _captureAnswerHotkey = false;
  LogicalKeyboardKey _answerHotkey = AppHotkeys.defaultAnswerHotkey;
  final FocusNode _hotkeyFocusNode = FocusNode();
  bool _suppressAutoSave = false;
  bool _saveInFlight = false;
  bool _savePending = false;
  Timer? _autoSaveDebounce;

  @override
  void initState() {
    super.initState();
    _loadVolume();
    _loadAnswerHotkey();
    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _nameCtrl.removeListener(_onNameChanged);
    _hotkeyFocusNode.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('profiles')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: LoadingPane());
          }

          final data = snapshot.data?.data() ?? <String, dynamic>{};
          if (!_profileLoaded) {
            _suppressAutoSave = true;
            _profileLoaded = true;
            _nameCtrl.text = (data['nickname'] as String? ?? '').trim();
            _avatarUrl = (data['avatarUrl'] as String? ?? '').trim();
            _suppressAutoSave = false;
          }

          final avatarImage = _avatarBytes != null
              ? MemoryImage(_avatarBytes!) as ImageProvider
              : (_avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Center(
                      child: MouseRegion(
                        cursor: _saving
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.click,
                        onEnter: (_) => _setAvatarHovered(true),
                        onExit: (_) => _setAvatarHovered(false),
                        child: GestureDetector(
                          onTap: _saving ? null : _pickAvatar,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 120),
                            curve: Curves.easeOut,
                            scale: (_avatarHovered && !_saving) ? 1.1 : 1.0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: 176,
                              height: 176,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _avatarHovered
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: DecoratedBox(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF1F2226),
                                        Color(0xFF2A2E33),
                                      ],
                                    ),
                                  ),
                                  child: avatarImage == null
                                      ? const Center(
                                          child: Icon(Icons.person, size: 72),
                                        )
                                      : Image(
                                          image: avatarImage,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      enabled: !_saving,
                      maxLength: 24,
                      decoration: InputDecoration(
                        labelText: context.l10n.settingsNameLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(context.l10n.settingsVolume((_volume * 100).round())),
                    Slider(
                      value: _volume,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      onChanged: (value) {
                        setState(() => _volume = value);
                        _scheduleAutoSave();
                      },
                    ),
                    const SizedBox(height: 12),
                    KeyboardListener(
                      focusNode: _hotkeyFocusNode,
                      onKeyEvent: _onHotkeyCaptureEvent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(context.l10n.answerHotkeyLabel),
                          const SizedBox(height: 8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _captureAnswerHotkey
                                          ? context.l10n.answerHotkeyPressAny
                                          : context.l10n.answerHotkeyCurrent(
                                              _displayKeyName(_answerHotkey),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: _toggleHotkeyCapture,
                                    child: Text(
                                      _captureAnswerHotkey
                                          ? context.l10n.cancel
                                          : context.l10n.change,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(child: LanguageSwitcher(enabled: !_saving)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadVolume() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getDouble('setting_volume');
    if (!mounted || value == null) return;
    setState(() => _volume = value.clamp(0.0, 1.0));
  }

  Future<void> _loadAnswerHotkey() async {
    final key = await AppHotkeys.loadAnswerHotkey();
    if (!mounted) return;
    setState(() => _answerHotkey = key);
  }

  void _toggleHotkeyCapture() {
    setState(() => _captureAnswerHotkey = !_captureAnswerHotkey);
    if (_captureAnswerHotkey) {
      _hotkeyFocusNode.requestFocus();
    } else {
      _hotkeyFocusNode.unfocus();
    }
  }

  Future<void> _onHotkeyCaptureEvent(KeyEvent event) async {
    if (!_captureAnswerHotkey || event is! KeyDownEvent) {
      return;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (mounted) {
        setState(() => _captureAnswerHotkey = false);
      }
      _hotkeyFocusNode.unfocus();
      return;
    }
    await AppHotkeys.saveAnswerHotkey(key);
    if (!mounted) return;
    setState(() {
      _answerHotkey = key;
      _captureAnswerHotkey = false;
    });
    _hotkeyFocusNode.unfocus();
  }

  String _displayKeyName(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) {
      return context.l10n.keySpace;
    }
    final label = key.keyLabel.trim();
    if (label.isNotEmpty) {
      return label;
    }
    return key.debugName ?? 'Key ${key.keyId}';
  }

  void _setAvatarHovered(bool value) {
    if (!mounted || _saving || _avatarHovered == value) {
      return;
    }
    setState(() => _avatarHovered = value);
  }

  Future<void> _pickAvatar() async {
    try {
      final bytes = await pickAvatarBytes();
      if (bytes == null || bytes.isEmpty || !mounted) return;
      setState(() => _avatarBytes = bytes);
      _scheduleAutoSave();
    } catch (error) {
      if (!mounted) return;
      showAppPopup(
        context,
        message: context.l10n.changeAvatarError(error.toString()),
        type: AppPopupType.error,
      );
    }
  }

  void _onNameChanged() {
    _scheduleAutoSave();
  }

  void _scheduleAutoSave([Duration delay = const Duration(milliseconds: 500)]) {
    if (!_profileLoaded || _suppressAutoSave) {
      return;
    }
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(delay, _save);
  }

  Future<void> _save() async {
    if (!_profileLoaded) {
      return;
    }
    if (_saveInFlight) {
      _savePending = true;
      return;
    }

    _saveInFlight = true;
    final name = _nameCtrl.text.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('setting_volume', _volume);

      if (name.isEmpty) {
        return;
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final avatarUrl = _avatarBytes == null
          ? _avatarUrl
          : _buildAvatarDataUrl(_avatarBytes!);

      await ref
          .read(gameRepositoryProvider)
          .upsertProfile(uid: uid, nickname: name, avatarUrl: avatarUrl);

      await prefs.setString('profile_nickname', name);
      await prefs.setString('profile_avatar', avatarUrl);

      if (!mounted) return;
      setState(() {
        _avatarUrl = avatarUrl;
        _avatarBytes = null;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      showAppPopup(
        context,
        message: context.l10n.saveError(error.toString()),
        type: AppPopupType.error,
      );
      debugPrint('settings save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _saveInFlight = false;
      if (_savePending) {
        _savePending = false;
        _scheduleAutoSave(const Duration(milliseconds: 200));
      }
    }
  }

  String _buildAvatarDataUrl(Uint8List bytes) {
    final safeBytes = Uint8List.fromList(bytes);
    final mime = _detectImageMime(safeBytes);
    return 'data:$mime;base64,${base64Encode(safeBytes)}';
  }

  String _detectImageMime(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return 'image/gif';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'application/octet-stream';
  }
}
