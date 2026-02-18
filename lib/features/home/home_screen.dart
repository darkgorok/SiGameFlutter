import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/l10n.dart';
import '../../core/widgets/app_popup.dart';
import '../game/application/game_providers.dart';
import '../packs/local_pack.dart';
import '../packs/pack_file.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.appTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => _showCreateRoomDialog(context, ref),
                  child: Text(context.l10n.homeCreateRoom),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.rooms),
                  child: Text(context.l10n.homeFindRoom),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.settings),
                  child: Text(context.l10n.homeSettings),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _showPackEditorChoice(context),
                  child: Text(context.l10n.packEditor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPackEditorChoice(BuildContext context) async {
    final action = await showDialog<_PackEditorAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.packEditor),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(_PackEditorAction.create),
                child: Text(context.l10n.packEditorCreate),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(_PackEditorAction.edit),
                child: Text(context.l10n.packEditorEdit),
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted || action == null) {
      return;
    }
    switch (action) {
      case _PackEditorAction.create:
        Navigator.of(context).pushNamed(AppRoutes.packEditorCreate);
        return;
      case _PackEditorAction.edit:
        Navigator.of(context).pushNamed(AppRoutes.packEditorEdit);
        return;
    }
  }

  Future<void> _showCreateRoomDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final roomNameCtrl = TextEditingController(
      text: context.l10n.newGameDefault,
    );
    final passwordCtrl = TextEditingController();
    final roomActions = ref.read(roomActionsProvider);
    final questionActions = ref.read(questionActionsProvider);

    LocalPackDocument? selectedPack;
    bool busy = false;

    Future<void> pickPack(StateSetter setDialogState) async {
      if (busy) return;
      final noQuestionsMessage = context.l10n.noQuestionsInFile;
      setDialogState(() => busy = true);
      try {
        final jsonText = await pickPackJsonText();
        if (jsonText == null || jsonText.trim().isEmpty) {
          return;
        }
        final raw = jsonDecode(jsonText);
        final pack = LocalPackDocument.fromJson(raw);
        if (pack.questions.isEmpty) {
          throw Exception(noQuestionsMessage);
        }
        selectedPack = pack;
      } catch (_) {
        if (!context.mounted) return;
        showAppPopup(
          context,
          message: context.l10n.packInvalidFile,
          type: AppPopupType.error,
        );
      } finally {
        setDialogState(() => busy = false);
      }
    }

    Future<void> createRoom(StateSetter setDialogState) async {
      if (busy) return;
      final roomName = roomNameCtrl.text.trim();
      final password = passwordCtrl.text.trim();
      if (roomName.isEmpty) {
        showAppPopup(
          context,
          message: context.l10n.roomNameRequired,
          type: AppPopupType.error,
        );
        return;
      }
      if (selectedPack == null) {
        showAppPopup(
          context,
          message: context.l10n.packFileRequired,
          type: AppPopupType.error,
        );
        return;
      }

      setDialogState(() => busy = true);
      try {
        final roomId = await roomActions.createRoom(
          roomName: roomName,
          password: password.isEmpty ? null : password,
        );
        await questionActions.addQuestions(
          roomId: roomId,
          drafts: selectedPack!.questions.map((q) => q.toDraft()).toList(),
        );
        if (!context.mounted) return;
        Navigator.of(context).pop();
        Navigator.of(
          context,
        ).pushNamed(AppRoutes.roomEditor, arguments: roomId);
      } catch (e) {
        if (!context.mounted) return;
        showAppPopup(
          context,
          message: context.l10n.createRoomError(e.toString()),
          type: AppPopupType.error,
        );
      } finally {
        if (context.mounted) {
          setDialogState(() => busy = false);
        }
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(context.l10n.createRoomDialogTitle),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: roomNameCtrl,
                      enabled: !busy,
                      decoration: InputDecoration(
                        labelText: context.l10n.roomNameLabel,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordCtrl,
                      enabled: !busy,
                      decoration: InputDecoration(
                        labelText: context.l10n.roomPasswordLabel,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => pickPack(setDialogState),
                      icon: const Icon(Icons.upload_file),
                      label: Text(context.l10n.packSelectFile),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedPack == null
                          ? context.l10n.packFileRequired
                          : context.l10n.questionsLoaded(
                              selectedPack!.questions.length,
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: busy ? null : () => createRoom(setDialogState),
                  child: Text(context.l10n.create),
                ),
              ],
            );
          },
        );
      },
    );

    roomNameCtrl.dispose();
    passwordCtrl.dispose();
  }
}

enum _PackEditorAction { create, edit }
