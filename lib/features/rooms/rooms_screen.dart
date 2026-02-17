import 'dart:convert';

import 'package:flutter/material.dart';
import '../../app/presentation/loading_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../game/application/game_providers.dart';
import '../game/game_models.dart';
import '../packs/local_pack.dart';
import '../packs/pack_file.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  final _nameCtrl = TextEditingController(text: 'Новая игра');
  bool _creating = false;

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
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        enabled: !_creating,
                        decoration: const InputDecoration(
                          labelText: 'Название комнаты',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _creating
                          ? null
                          : () => _createEmptyRoom(actions),
                      child: _creating
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: LoadingInline(),
                            )
                          : const Text('Создать'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _creating
                            ? null
                            : () => _createRoomFromPackFile(actions),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Создать и загрузить пак из файла'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _creating
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.packEditor),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Редактор пака'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: roomsAsync.when(
              loading: () => const Center(child: LoadingPane()),
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

  String get _roomName {
    final name = _nameCtrl.text.trim();
    return name.isEmpty ? 'Комната' : name;
  }

  Future<void> _createEmptyRoom(GameActionsController actions) async {
    setState(() => _creating = true);
    try {
      final roomId = await actions.createRoom(roomName: _roomName);
      if (!mounted) return;
      Navigator.of(context).pushNamed(AppRoutes.roomEditor, arguments: roomId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка создания комнаты: $e')));
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _createRoomFromPackFile(GameActionsController actions) async {
    setState(() => _creating = true);
    try {
      final jsonText = await pickPackJsonText();
      if (jsonText == null || jsonText.trim().isEmpty) {
        return;
      }
      final raw = jsonDecode(jsonText);
      final pack = LocalPackDocument.fromJson(raw);
      if (pack.questions.isEmpty) {
        throw Exception('В файле нет вопросов');
      }

      final roomId = await actions.createRoom(roomName: _roomName);
      for (final question in pack.questions) {
        await actions.addQuestion(roomId: roomId, draft: question.toDraft());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Загружено вопросов: ${pack.questions.length}')),
      );
      Navigator.of(context).pushNamed(AppRoutes.roomEditor, arguments: roomId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки пака: $e')));
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }
}
