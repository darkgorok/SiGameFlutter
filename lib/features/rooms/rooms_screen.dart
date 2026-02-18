import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/presentation/loading_screen.dart';
import '../../app/router.dart';
import '../../core/l10n.dart';
import '../../core/widgets/app_popup.dart';
import '../game/application/game_providers.dart';
import '../game/game_localizations.dart';
import '../game/game_models.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  @override
  Widget build(BuildContext context) {
    final actions = ref.read(gameActionsControllerProvider.notifier);
    final roomsAsync = ref.watch(roomsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.roomsTitle)),
      body: roomsAsync.when(
        loading: () => const Center(child: LoadingPane()),
        error: (error, stackTrace) => Center(
          child: Text(context.l10n.errorWithDetails(error.toString())),
        ),
        data: (rooms) {
          if (rooms.isEmpty) {
            return Center(child: Text(context.l10n.noRoomsYet));
          }
          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(room.name)),
                      if (room.passwordProtected)
                        const Icon(Icons.lock_outline, size: 18),
                    ],
                  ),
                  subtitle: Text(
                    context.l10n.roomStatusPhase(
                      room.status.localizedLabel(context),
                      room.phase.localizedLabel(context),
                    ),
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => _joinAs(
                          actions: actions,
                          room: room,
                          role: PlayerRole.player,
                        ),
                        child: Text(context.l10n.player),
                      ),
                      OutlinedButton(
                        onPressed: () => _joinAs(
                          actions: actions,
                          room: room,
                          role: PlayerRole.spectator,
                        ),
                        child: Text(context.l10n.spectator),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _joinAs({
    required GameActionsController actions,
    required RoomModel room,
    required PlayerRole role,
  }) async {
    String? password;
    if (room.passwordProtected) {
      password = await _askRoomPassword(room.name);
      if (password == null) {
        return;
      }
    }
    try {
      await actions.joinRoom(room.id, role: role, password: password);
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        AppRoutes.room,
        arguments: RoomRouteArgs(roomId: room.id, role: role),
      );
    } catch (e) {
      if (!mounted) return;
      showAppPopup(
        context,
        message: context.l10n.errorWithDetails(e.toString()),
        type: AppPopupType.error,
      );
    }
  }

  Future<String?> _askRoomPassword(String roomName) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.enterRoomPasswordTitle(roomName)),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.l10n.roomPasswordLabel,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(ctrl.text.trim()),
              child: Text(context.l10n.continueButton),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    if (result == null) {
      return null;
    }
    return result;
  }
}
