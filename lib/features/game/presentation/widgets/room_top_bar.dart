import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n.dart';
import '../../application/game_providers.dart';
import '../../game_localizations.dart';
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
    final roomActions = ref.read(roomActionsProvider);
    final questionActions = ref.read(questionActionsProvider);
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${room.name} | ${room.status.localizedLabel(context)} | ${room.phase.localizedLabel(context)} | ${context.l10n.roundLabel} ${room.currentRound}',
            ),
            if (room.chooserUid != null)
              Text('${context.l10n.questionChooser}: ${room.chooserUid}'),
            if (room.timerDeadlineAtMs != null)
              CountdownLabel(
                deadlineMs: room.timerDeadlineAtMs!,
                onExpired: isHost
                    ? () => questionActions.handleTimerExpiration(roomId)
                    : null,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  key: const ValueKey('room_start_game_button'),
                  onPressed: isHost
                      ? () => roomActions.startGame(roomId)
                      : null,
                  child: Text(context.l10n.start),
                ),
                ElevatedButton(
                  key: const ValueKey('room_pause_resume_button'),
                  onPressed: room.status == GameStatus.paused
                      ? (canResume
                            ? () => roomActions.resumeGame(roomId)
                            : null)
                      : (canPause ? () => roomActions.pauseGame(roomId) : null),
                  child: Text(
                    room.status == GameStatus.paused
                        ? context.l10n.unpause
                        : context.l10n.pause,
                  ),
                ),
                ElevatedButton(
                  key: const ValueKey('room_round2_button'),
                  onPressed: isHost
                      ? () => roomActions.advanceToRound2(roomId)
                      : null,
                  child: Text(
                    '${context.l10n.roundLabel} ${room.currentRound + 1}',
                  ),
                ),
                ElevatedButton(
                  key: const ValueKey('room_start_final_round_button'),
                  onPressed: isHost
                      ? () => roomActions.startFinalRound(roomId)
                      : null,
                  child: Text(context.l10n.finalRoundButton),
                ),
                ElevatedButton(
                  key: const ValueKey('room_open_editor_button'),
                  onPressed: canEdit ? onOpenEditor : null,
                  child: Text(context.l10n.packEditor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
