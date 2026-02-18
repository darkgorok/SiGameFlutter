import 'dart:typed_data';

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/presentation/loading_screen.dart';
import '../../app/router.dart';
import '../../core/avatar_data_url.dart';
import '../../core/errors/app_exception.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/runtime_flags.dart';
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
                            key: const ValueKey('profile_nickname_field'),
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
                            key: const ValueKey('profile_continue_button'),
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
      final avatarUrl = buildAvatarDataUrl(_avatarBytes);

      if (!e2eBypassProfileUpsert) {
        await ref
            .read(gameRepositoryProvider)
            .upsertProfile(uid: uid, nickname: nickname, avatarUrl: avatarUrl)
            .timeout(const Duration(seconds: 20));
      }

      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setString('profile_nickname', nickname);
      await prefs.setString('profile_avatar', avatarUrl);

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } on TimeoutException catch (error, stackTrace) {
      if (!mounted) return;
      showAppPopup(
        context,
        message: context.l10n.saveError(
          'Request timed out. Please check network/emulator and try again.',
        ),
        type: AppPopupType.error,
      );
      debugPrint('profile save timeout: $error');
      debugPrintStack(stackTrace: stackTrace);
    } catch (error, stackTrace) {
      if (!mounted) return;
      showAppPopup(
        context,
        message: context.l10n.saveError(_profileSaveErrorMessage(error)),
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

  String _profileSaveErrorMessage(Object error) {
    if (error is AppException) {
      final message = error.message.toLowerCase();
      if (error.code == 'already-exists' ||
          (error.code == 'failed-precondition' &&
              message.contains('nickname'))) {
        return 'Nickname is already taken. Please choose another one.';
      }
      return error.message;
    }
    final raw = error.toString();
    if (raw.toLowerCase().contains('nickname')) {
      return 'Nickname is already taken. Please choose another one.';
    }
    return raw;
  }
}
