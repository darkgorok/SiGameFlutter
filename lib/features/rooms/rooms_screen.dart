import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/presentation/loading_screen.dart';
import '../../app/router.dart';
import '../../core/errors/app_exception.dart';
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
    final actions = ref.read(roomActionsProvider);
    final roomsAsync = ref.watch(roomsPaginationControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.roomsTitle)),
      body: roomsAsync.when(
        loading: () => const Center(child: LoadingPane()),
        error: (error, stackTrace) => Center(
          child: Text(context.l10n.errorWithDetails(error.toString())),
        ),
        data: (roomsState) {
          if (roomsState.rooms.isEmpty) {
            return Center(child: Text(context.l10n.noRoomsYet));
          }
          return ListView(
            children: [
              ...roomsState.rooms.map((room) {
                return Card(
                  key: ValueKey('rooms_room_card_${room.id}'),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
                          key: ValueKey('rooms_join_player_${room.id}'),
                          onPressed: () => _joinAs(
                            actions: actions,
                            room: room,
                            role: PlayerRole.player,
                          ),
                          child: Text(context.l10n.player),
                        ),
                        OutlinedButton(
                          key: ValueKey('rooms_join_spectator_${room.id}'),
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
              }),
              if (roomsState.hasMore || roomsState.loadingMore)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: OutlinedButton(
                      onPressed: roomsState.loadingMore
                          ? null
                          : () => ref
                                .read(
                                  roomsPaginationControllerProvider.notifier,
                                )
                                .loadMore(),
                      child: roomsState.loadingMore
                          ? const LoadingInline()
                          : Text(context.l10n.continueButton),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _joinAs({
    required RoomActions actions,
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
      final message = _joinRoomErrorMessage(e);
      showAppPopup(
        context,
        message: message,
        type: AppPopupType.error,
      );
    }
  }

  String _joinRoomErrorMessage(Object error) {
    if (error is AppException) {
      if (error.code == 'permission-denied') {
        return 'Invalid room password.';
      }
      if (error.code == 'failed-precondition' &&
          error.message.toLowerCase().contains('password')) {
        return 'Room password is required.';
      }
      return error.message;
    }
    return error.toString();
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
