import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/loading_screen.dart';
import '../../../../core/l10n.dart';
import '../../application/game_providers.dart';
import '../../game_localizations.dart';
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
            context.l10n.playersAndStats,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: context.l10n.tabPlayers),
                    Tab(text: context.l10n.tabGameLog),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      playersAsync.when(
                        loading: () => const Center(child: LoadingPane()),
                        error: (error, stackTrace) => Center(
                          child: Text(
                            context.l10n.errorWithDetails(error.toString()),
                          ),
                        ),
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
                                        '${p.nickname} (${p.role.localizedLabel(context)}) ${p.connected ? '' : '(${context.l10n.offline})'}',
                                      ),
                                      Text(
                                        '${context.l10n.scoreLabel}: ${p.score}',
                                      ),
                                      Text(
                                        context.l10n.statsLine(
                                          p.correctAnswers,
                                          p.wrongAnswers,
                                          p.buzzCount,
                                        ),
                                      ),
                                      if (widget.isHost)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _deltaCtrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  labelText: context
                                                      .l10n
                                                      .manualAdjustment,
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
                                              items: [
                                                DropdownMenuItem(
                                                  value: PlayerRole.player,
                                                  child: Text(
                                                    context.l10n.rolePlayer,
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: PlayerRole.editor,
                                                  child: Text(
                                                    context.l10n.roleEditor,
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: PlayerRole.spectator,
                                                  child: Text(
                                                    context.l10n.roleSpectator,
                                                  ),
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
                                              child: Text(context.l10n.kick),
                                            ),
                                            OutlinedButton(
                                              onPressed: () =>
                                                  actions.banPlayer(
                                                    roomId: widget.roomId,
                                                    targetUid: p.uid,
                                                  ),
                                              child: Text(context.l10n.ban),
                                            ),
                                            OutlinedButton(
                                              onPressed: () =>
                                                  actions.unbanPlayer(
                                                    roomId: widget.roomId,
                                                    targetUid: p.uid,
                                                  ),
                                              child: Text(context.l10n.unban),
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
                        error: (error, stackTrace) => Center(
                          child: Text(
                            context.l10n.errorWithDetails(error.toString()),
                          ),
                        ),
                        data: (events) {
                          if (events.isEmpty) {
                            return Center(
                              child: Text(context.l10n.noEventsYet),
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
