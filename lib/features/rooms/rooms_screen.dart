import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../game/application/game_providers.dart';
import '../game/game_models.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  final _nameCtrl = TextEditingController(text: 'Новая игра');

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.read(gameActionsControllerProvider.notifier);
    final roomsAsync = ref.watch(roomsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Комнаты')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Название комнаты',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final roomId = await actions.createRoom(
                      roomName: _nameCtrl.text.trim().isEmpty
                          ? 'Комната'
                          : _nameCtrl.text.trim(),
                    );
                    if (!context.mounted) return;
                    Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.roomEditor, arguments: roomId);
                  },
                  child: const Text('Создать'),
                ),
              ],
            ),
          ),
          Expanded(
            child: roomsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text('Ошибка: $error')),
              data: (rooms) {
                if (rooms.isEmpty) {
                  return const Center(child: Text('Комнат пока нет'));
                }
                return ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        title: Text(room.name),
                        subtitle: Text(
                          'Статус: ${room.status.label} | Этап: ${room.phase.label}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                await actions.joinRoom(
                                  room.id,
                                  role: PlayerRole.player,
                                );
                                if (!context.mounted) return;
                                Navigator.of(context).pushNamed(
                                  AppRoutes.room,
                                  arguments: RoomRouteArgs(
                                    roomId: room.id,
                                    role: PlayerRole.player,
                                  ),
                                );
                              },
                              child: const Text('Игрок'),
                            ),
                            OutlinedButton(
                              onPressed: () async {
                                await actions.joinRoom(
                                  room.id,
                                  role: PlayerRole.spectator,
                                );
                                if (!context.mounted) return;
                                Navigator.of(context).pushNamed(
                                  AppRoutes.room,
                                  arguments: RoomRouteArgs(
                                    roomId: room.id,
                                    role: PlayerRole.spectator,
                                  ),
                                );
                              },
                              child: const Text('Зритель'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
