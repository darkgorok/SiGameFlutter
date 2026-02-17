import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app/presentation/loading_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router.dart';
import '../../core/providers.dart';
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

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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
                    'Создание профиля',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: CircleAvatar(
                      radius: 44,
                      backgroundImage: _avatarBytes == null
                          ? null
                          : MemoryImage(_avatarBytes!),
                      child: _avatarBytes == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickAvatar,
                    icon: const Icon(Icons.upload),
                    label: const Text('Загрузить аватарку'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nicknameCtrl,
                    enabled: !_saving,
                    maxLength: 24,
                    decoration: const InputDecoration(
                      labelText: 'Никнейм (обязательно)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const LoadingInline()
                        : const Text('Продолжить'),
                  ),
                ],
              ),
            ),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось выбрать аватарку: $error')),
      );
    }
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Нужно указать никнейм')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $error')));
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
    // Copy into a plain Uint8List to avoid platform-specific typed data views.
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
