import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/presentation/loading_screen.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/widgets/app_popup.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nickCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _nickCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.profileTitle)),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('profiles')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: LoadingPane());
          }
          final data = snapshot.data?.data() ?? {};
          if (!_loaded) {
            _loaded = true;
            _nickCtrl.text = data['nickname'] as String? ?? '';
            _avatarCtrl.text = data['avatarUrl'] as String? ?? '';
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    TextField(
                      controller: _nickCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.profileNickLabel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _avatarCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.profileAvatarUrlLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        await ref
                            .read(gameRepositoryProvider)
                            .upsertProfile(
                              uid: uid,
                              nickname: _nickCtrl.text.trim(),
                              avatarUrl: _avatarCtrl.text.trim(),
                            );
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(
                          'profile_nickname',
                          _nickCtrl.text.trim(),
                        );
                        await prefs.setString(
                          'profile_avatar',
                          _avatarCtrl.text.trim(),
                        );
                        if (!mounted) return;
                        showAppPopup(
                          context,
                          message: context.l10n.profileSaved,
                          type: AppPopupType.success,
                        );
                      },
                      child: Text(context.l10n.save),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
