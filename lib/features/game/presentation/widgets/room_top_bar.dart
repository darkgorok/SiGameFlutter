import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_providers.dart';
import '../../game_models.dart';
import 'countdown_label.dart';

class RoomTopBar extends ConsumerWidget {
  const RoomTopBar({
    super.key,
    required this.room,
    required this.isHost,
    required this.canResume,
    required this.canPause,
    required this.canEdit,
    required this.roomId,
    required this.onOpenEditor,
  });

  final RoomModel room;
  final bool isHost;
  final bool canResume;
  final bool canPause;
  final bool canEdit;
  final String roomId;
  final VoidCallback onOpenEditor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(gameActionsControllerProvider.notifier);
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${room.name} | ${room.status.label} | ${room.phase.label} | Раунд ${room.currentRound}',
            ),
            if (room.chooserUid != null)
              Text('Выбор вопроса: ${room.chooserUid}'),
            if (room.timerDeadlineAtMs != null)
              CountdownLabel(
                deadlineMs: room.timerDeadlineAtMs!,
                onExpired: isHost
                    ? () => actions.handleTimerExpiration(roomId)
                    : null,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: isHost ? () => actions.startGame(roomId) : null,
                  child: const Text('Старт'),
                ),
                ElevatedButton(
                  onPressed: room.status == GameStatus.paused
                      ? (canResume ? () => actions.resumeGame(roomId) : null)
                      : (canPause ? () => actions.pauseGame(roomId) : null),
                  child: Text(
                    room.status == GameStatus.paused ? 'Снять паузу' : 'Пауза',
                  ),
                ),
                ElevatedButton(
                  onPressed: isHost
                      ? () => actions.advanceToRound2(roomId)
                      : null,
                  child: const Text('Раунд 2'),
                ),
                ElevatedButton(
                  onPressed: isHost
                      ? () => actions.startFinalRound(roomId)
                      : null,
                  child: const Text('Финал'),
                ),
                ElevatedButton(
                  onPressed: canEdit ? onOpenEditor : null,
                  child: const Text('Редактор'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
