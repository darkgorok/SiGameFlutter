import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/loading_screen.dart';
import '../../../../core/l10n.dart';
import '../../application/game_providers.dart';
import '../../game_localizations.dart';
import '../../game_models.dart';
import '../controllers/game_ui_permissions.dart';

class QuestionBoard extends ConsumerWidget {
  const QuestionBoard({
    super.key,
    required this.room,
    required this.roomId,
    required this.myRole,
  });

  final RoomModel room;
  final String roomId;
  final PlayerRole myRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(questionsStreamProvider(roomId));
    final actions = ref.read(gameActionsControllerProvider.notifier);
    return questionsAsync.when(
      loading: () => const Center(child: LoadingPane()),
      error: (error, stackTrace) =>
          Center(child: Text(context.l10n.errorWithDetails(error.toString()))),
      data: (allQuestions) {
        final questions = allQuestions
            .where((q) => q.round == room.currentRound)
            .toList();
        if (questions.isEmpty) {
          return Center(child: Text(context.l10n.noQuestionsCurrentRound));
        }
        final grouped = <String, List<QuestionModel>>{};
        for (final q in questions) {
          grouped.putIfAbsent(q.theme, () => []).add(q);
        }
        final themes = grouped.keys.toList()..sort();
        for (final list in grouped.values) {
          list.sort((a, b) => a.cost.compareTo(b.cost));
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (room.activeQuestion != null)
              ActiveQuestionPanel(room: room, roomId: roomId, myRole: myRole),
            ...themes.map((theme) {
              final cells = grouped[theme]!;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cells.map((q) {
                          return ElevatedButton(
                            onPressed:
                                GameUiPermissions.canPickQuestion(room) &&
                                    !q.used
                                ? () => actions.pickQuestion(
                                    roomId: roomId,
                                    questionId: q.id,
                                  )
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: q.used ? Colors.grey : null,
                            ),
                            child: Text('${q.cost}'),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class ActiveQuestionPanel extends ConsumerWidget {
  const ActiveQuestionPanel({
    super.key,
    required this.room,
    required this.roomId,
    required this.myRole,
  });

  final RoomModel room;
  final String roomId;
  final PlayerRole myRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = room.activeQuestion;
    if (active == null) {
      return const SizedBox.shrink();
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final isHost = uid == room.hostUid;
    final actions = ref.read(gameActionsControllerProvider.notifier);

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.activeQuestionHeader(
                active.theme,
                active.type.localizedLabel(context),
                active.cost,
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(active.text),
            if (active.mediaUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${context.l10n.mediaLabel}: ${active.mediaType.localizedLabel(context)}',
              ),
              if (active.mediaType == QuestionMediaType.image)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _QuestionImagePreview(url: active.mediaUrl),
                )
              else
                Text(active.mediaUrl),
            ],
            const SizedBox(height: 6),
            if (room.phase == GamePhase.questionReveal && isHost)
              ElevatedButton(
                onPressed: () => actions.openBuzzing(roomId),
                child: Text(context.l10n.openAnswerButton),
              ),
            if (room.phase == GamePhase.catTargeting)
              CatTargetingPanel(roomId: roomId, room: room),
            if (room.phase == GamePhase.wagerBidding)
              WagerPanel(roomId: roomId, room: room),
            if (room.phase == GamePhase.answering)
              active.type == QuestionType.closestNumber
                  ? NumericAnswerPanel(
                      room: room,
                      roomId: roomId,
                      myRole: myRole,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (room.currentAttemptUid != null)
                          Text(
                            '${context.l10n.answeringNow}: ${room.currentAttemptUid}',
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton(
                              onPressed: room.currentAttemptUid == uid
                                  ? () => actions.submitAnswer(roomId)
                                  : null,
                              child: Text(context.l10n.answeredByVoice),
                            ),
                            ElevatedButton(
                              onPressed:
                                  GameUiPermissions.canBuzz(room, uid) &&
                                      myRole != PlayerRole.spectator
                                  ? () => actions.buzz(roomId)
                                  : null,
                              child: Text(context.l10n.buzzButton),
                            ),
                          ],
                        ),
                      ],
                    ),
            if (room.phase == GamePhase.answerReview && isHost)
              HostJudgePanel(roomId: roomId, room: room),
            if (room.phase == GamePhase.answerReview && !isHost)
              Text(context.l10n.waitingHostDecision),
            if (room.phase == GamePhase.boardSelect)
              Text(context.l10n.chooseNextQuestion),
          ],
        ),
      ),
    );
  }
}

class _QuestionImagePreview extends StatelessWidget {
  const _QuestionImagePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:image/')) {
      final comma = url.indexOf(',');
      if (comma > 0) {
        try {
          final encoded = url.substring(comma + 1);
          final bytes = base64Decode(encoded);
          return Image.memory(bytes, height: 200, errorBuilder: _errorBuilder);
        } catch (_) {
          return _errorBuilder(context, 'invalid_data_url', null);
        }
      }
    }
    return Image.network(url, height: 200, errorBuilder: _errorBuilder);
  }

  Widget _errorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return const SizedBox(
      height: 200,
      child: Center(child: Text('Media preview unavailable')),
    );
  }
}

class NumericAnswerPanel extends ConsumerStatefulWidget {
  const NumericAnswerPanel({
    super.key,
    required this.room,
    required this.roomId,
    required this.myRole,
  });

  final RoomModel room;
  final String roomId;
  final PlayerRole myRole;

  @override
  ConsumerState<NumericAnswerPanel> createState() => _NumericAnswerPanelState();
}

class _NumericAnswerPanelState extends ConsumerState<NumericAnswerPanel> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAnswer = widget.myRole != PlayerRole.spectator;
    final actions = ref.read(gameActionsControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.closestNumberHint),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.numericAnswerFieldLabel,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: !canAnswer
                  ? null
                  : () async {
                      final value = num.tryParse(_ctrl.text.trim());
                      if (value == null) {
                        return;
                      }
                      await actions.submitNumericAnswer(
                        roomId: widget.roomId,
                        value: value,
                      );
                    },
              child: Text(context.l10n.submitNumericAnswer),
            ),
          ],
        ),
      ],
    );
  }
}

class CatTargetingPanel extends ConsumerWidget {
  const CatTargetingPanel({
    super.key,
    required this.roomId,
    required this.room,
  });

  final String roomId;
  final RoomModel room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersStreamProvider(roomId));
    final actions = ref.read(gameActionsControllerProvider.notifier);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (uid != room.chooserUid && uid != room.hostUid) {
      return Text(context.l10n.waitingCatSelection);
    }
    return playersAsync.when(
      loading: () => const LoadingInline(),
      error: (error, stackTrace) =>
          Text(context.l10n.errorWithDetails(error.toString())),
      data: (players) {
        final candidates = players
            .where((p) => p.role != PlayerRole.spectator)
            .toList();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: candidates
              .map(
                (p) => OutlinedButton(
                  onPressed: () => actions.selectCatTarget(roomId, p.uid),
                  child: Text(context.l10n.transferTo(p.nickname)),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class WagerPanel extends ConsumerStatefulWidget {
  const WagerPanel({super.key, required this.roomId, required this.room});

  final String roomId;
  final RoomModel room;

  @override
  ConsumerState<WagerPanel> createState() => _WagerPanelState();
}

class _WagerPanelState extends ConsumerState<WagerPanel> {
  final _wagerCtrl = TextEditingController(text: '100');

  @override
  void dispose() {
    _wagerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final room = widget.room;
    final actions = ref.read(gameActionsControllerProvider.notifier);
    final canSetWager = uid == room.chooserUid || uid == room.hostUid;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _wagerCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.l10n.wagerLabel),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: canSetWager
              ? () => actions.setWagerAndOpen(
                  roomId: widget.roomId,
                  wager: int.tryParse(_wagerCtrl.text.trim()) ?? 100,
                )
              : null,
          child: Text(context.l10n.confirmWager),
        ),
      ],
    );
  }
}

class HostJudgePanel extends ConsumerWidget {
  const HostJudgePanel({super.key, required this.roomId, required this.room});

  final String roomId;
  final RoomModel room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(gameActionsControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.whoAnswered(room.currentAttemptUid ?? '-')),
        Text(context.l10n.hostVoiceCheck),
        if (room.activeQuestion != null &&
            room.activeQuestion!.aliases.isNotEmpty)
          Text(
            context.l10n.acceptedAnswers(
              room.activeQuestion!.aliases.join(', '),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              onPressed: () =>
                  actions.judgeAnswer(roomId: roomId, correct: true),
              child: Text(context.l10n.finalResultCorrect),
            ),
            ElevatedButton(
              onPressed: () =>
                  actions.judgeAnswer(roomId: roomId, correct: false),
              child: Text(context.l10n.finalResultWrong),
            ),
          ],
        ),
      ],
    );
  }
}
