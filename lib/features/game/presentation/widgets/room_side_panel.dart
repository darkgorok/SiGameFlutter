import 'package:flutter/material.dart';
import '../../../../app/presentation/loading_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../application/game_providers.dart';
import '../../game_models.dart';

class RoomSidePanel extends ConsumerStatefulWidget {
  const RoomSidePanel({
    super.key,
    required this.room,
    required this.roomId,
    required this.isHost,
  });

  final RoomModel room;
  final String roomId;
  final bool isHost;

  @override
  ConsumerState<RoomSidePanel> createState() => _RoomSidePanelState();
}

class _RoomSidePanelState extends ConsumerState<RoomSidePanel> {
  final _deltaCtrl = TextEditingController(text: '100');

  @override
  void dispose() {
    _deltaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final actions = ref.read(gameActionsControllerProvider.notifier);
    final playersAsync = ref.watch(playersStreamProvider(widget.roomId));
    final eventsAsync = ref.watch(eventsStreamProvider(widget.roomId));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Игроки и статистика',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Игроки'),
                    Tab(text: 'Лог партии'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      playersAsync.when(
                        loading: () => const Center(child: LoadingPane()),
                        error: (error, stackTrace) =>
                            Center(child: Text('Ошибка: $error')),
                        data: (players) {
                          return ListView.builder(
                            itemCount: players.length,
                            itemBuilder: (context, index) {
                              final p = players[index];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${p.nickname} (${p.role.label}) ${p.connected ? '' : '(offline)'}',
                                      ),
                                      Text('Счёт: ${p.score}'),
                                      Text(
                                        'Стат: +${p.correctAnswers} / -${p.wrongAnswers} | Кнопка: ${p.buzzCount}',
                                      ),
                                      if (widget.isHost)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _deltaCtrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          'Ручная корректировка',
                                                    ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  actions.applyScore(
                                                    roomId: widget.roomId,
                                                    targetUid: p.uid,
                                                    delta:
                                                        int.tryParse(
                                                          _deltaCtrl.text
                                                              .trim(),
                                                        ) ??
                                                        100,
                                                  ),
                                              icon: const Icon(Icons.add),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  actions.applyScore(
                                                    roomId: widget.roomId,
                                                    targetUid: p.uid,
                                                    delta:
                                                        -(int.tryParse(
                                                              _deltaCtrl.text
                                                                  .trim(),
                                                            ) ??
                                                            100),
                                                  ),
                                              icon: const Icon(Icons.remove),
                                            ),
                                          ],
                                        ),
                                      if (widget.isHost && p.uid != myUid)
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            DropdownButton<PlayerRole>(
                                              value: p.role == PlayerRole.host
                                                  ? PlayerRole.player
                                                  : p.role,
                                              items: const [
                                                DropdownMenuItem(
                                                  value: PlayerRole.player,
                                                  child: Text('Игрок'),
                                                ),
                                                DropdownMenuItem(
                                                  value: PlayerRole.editor,
                                                  child: Text('Редактор'),
                                                ),
                                                DropdownMenuItem(
                                                  value: PlayerRole.spectator,
                                                  child: Text('Зритель'),
                                                ),
                                              ],
                                              onChanged: (v) {
                                                if (v == null) return;
                                                actions.setPlayerRole(
                                                  roomId: widget.roomId,
                                                  targetUid: p.uid,
                                                  role: v,
                                                );
                                              },
                                            ),
                                            OutlinedButton(
                                              onPressed: () =>
                                                  actions.kickPlayer(
                                                    roomId: widget.roomId,
                                                    targetUid: p.uid,
                                                  ),
                                              child: const Text('Кик'),
                                            ),
                                            OutlinedButton(
                                              onPressed: () =>
                                                  actions.banPlayer(
                                                    roomId: widget.roomId,
                                                    targetUid: p.uid,
                                                  ),
                                              child: const Text('Бан'),
                                            ),
                                            OutlinedButton(
                                              onPressed: () =>
                                                  actions.unbanPlayer(
                                                    roomId: widget.roomId,
                                                    targetUid: p.uid,
                                                  ),
                                              child: const Text('Разбан'),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      eventsAsync.when(
                        loading: () => const Center(child: LoadingPane()),
                        error: (error, stackTrace) =>
                            Center(child: Text('Ошибка: $error')),
                        data: (events) {
                          if (events.isEmpty) {
                            return const Center(
                              child: Text('Событий пока нет'),
                            );
                          }
                          return ListView.builder(
                            itemCount: events.length,
                            itemBuilder: (context, index) {
                              final e = events[index];
                              return ListTile(
                                dense: true,
                                title: Text(e.message),
                                subtitle: Text(
                                  '${e.type} | ${e.actorUid} | ${e.createdAt ?? ''}',
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
