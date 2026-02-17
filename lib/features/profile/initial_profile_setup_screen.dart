import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
                        ? const CircularProgressIndicator()
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
      final avatarUrl = _avatarBytes == null
          ? ''
          : 'data:image/jpeg;base64,${base64Encode(_avatarBytes!)}';

      await ref
          .read(gameRepositoryProvider)
          .upsertProfile(uid: uid, nickname: nickname, avatarUrl: avatarUrl);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_nickname', nickname);
      await prefs.setString('profile_avatar', avatarUrl);

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
