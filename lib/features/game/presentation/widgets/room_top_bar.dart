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
    final players = ref.watch(playersStreamProvider(roomId)).valueOrNull;
    final isPaused = room.status == GameStatus.paused;
    final isLobby =
        room.status == GameStatus.lobby && room.phase == GamePhase.lobby;
    final isFinalState =
        room.status == GameStatus.finalRound ||
        room.phase == GamePhase.finalSetup ||
        room.phase == GamePhase.finalWagering ||
        room.phase == GamePhase.finalAnswering ||
        room.phase == GamePhase.finalReveal;
    final isCompletedState =
        room.status == GameStatus.completed || room.phase == GamePhase.gameOver;
    final canStartGame = isHost && isLobby;
    final canAdvanceRound2 =
        isHost &&
        !isPaused &&
        !isFinalState &&
        !isCompletedState &&
        room.currentRound < 2;
    final canStartFinalRound =
        isHost && !isPaused && !isFinalState && !isCompletedState;
    final canPauseCurrent = canPause && !isCompletedState;
    String resolvePlayerName(String uid) {
      if (uid.isEmpty) {
        return uid;
      }
      if (players != null) {
        for (final p in players) {
          if (p.uid == uid) {
            return p.nickname;
          }
        }
      }
      return uid;
    }

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
              Text(
                '${context.l10n.questionChooser}: ${resolvePlayerName(room.chooserUid!)}',
              ),
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
                  onPressed: canStartGame
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
                      : (canPauseCurrent
                            ? () => roomActions.pauseGame(roomId)
                            : null),
                  child: Text(
                    room.status == GameStatus.paused
                        ? context.l10n.unpause
                        : context.l10n.pause,
                  ),
                ),
                ElevatedButton(
                  key: const ValueKey('room_round2_button'),
                  onPressed: canAdvanceRound2
                      ? () => roomActions.advanceToRound2(roomId)
                      : null,
                  child: Text(context.l10n.round2),
                ),
                ElevatedButton(
                  key: const ValueKey('room_start_final_round_button'),
                  onPressed: canStartFinalRound
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
