import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/presentation/loading_screen.dart';
import '../../app/router.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/widgets/app_popup.dart';
import '../../core/widgets/language_switcher.dart';
import 'avatar_picker.dart';

class InitialProfileSetupScreen extends ConsumerStatefulWidget {
  const InitialProfileSetupScreen({super.key});

  @override
  ConsumerState<InitialProfileSetupScreen> createState() =>
      _InitialProfileSetupScreenState();
}

class _InitialProfileSetupScreenState
    extends ConsumerState<InitialProfileSetupScreen> {
  final _nicknameCtrl = TextEditingController();
  Uint8List? _avatarBytes;
  bool _saving = false;
  bool _avatarHovered = false;

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.l10n.profileSetupTitle,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
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
                                  scale: (_avatarHovered && !_saving)
                                      ? 1.1
                                      : 1.0,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    width: 176,
                                    height: 176,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _avatarHovered
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
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
                                        child: _avatarBytes == null
                                            ? const Center(
                                                child: Icon(
                                                  Icons.person,
                                                  size: 72,
                                                ),
                                              )
                                            : Image(
                                                image: MemoryImage(
                                                  _avatarBytes!,
                                                ),
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nicknameCtrl,
                            enabled: !_saving,
                            textAlign: TextAlign.center,
                            maxLength: 24,
                            decoration: InputDecoration(
                              hintText: context.l10n.nicknameRequiredHint,
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _saving ? null : _saveProfile,
                            child: _saving
                                ? const LoadingInline()
                                : Text(context.l10n.continueButton),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Center(child: LanguageSwitcher(enabled: !_saving)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    try {
      final bytes = await pickAvatarBytes();
      if (bytes == null || bytes.isEmpty) return;
      if (!mounted) return;
      setState(() => _avatarBytes = bytes);
    } catch (error) {
      if (!mounted) return;
      showAppPopup(
        context,
        message: context.l10n.changeAvatarError(error.toString()),
        type: AppPopupType.error,
      );
    }
  }

  void _setAvatarHovered(bool value) {
    if (!mounted || _saving || _avatarHovered == value) {
      return;
    }
    setState(() => _avatarHovered = value);
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) {
      showAppPopup(
        context,
        message: context.l10n.nicknameRequired,
        type: AppPopupType.error,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final avatarUrl = _buildAvatarDataUrl(_avatarBytes);

      await ref
          .read(gameRepositoryProvider)
          .upsertProfile(uid: uid, nickname: nickname, avatarUrl: avatarUrl);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_nickname', nickname);
      await prefs.setString('profile_avatar', avatarUrl);

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } catch (error, stackTrace) {
      if (!mounted) return;
      showAppPopup(
        context,
        message: context.l10n.saveError(error.toString()),
        type: AppPopupType.error,
      );
      debugPrint('profile save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _buildAvatarDataUrl(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return '';
    }
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
