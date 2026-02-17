import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_providers.dart';
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Ошибка: $error')),
      data: (allQuestions) {
        final questions = allQuestions
            .where((q) => q.round == room.currentRound)
            .toList();
        if (questions.isEmpty) {
          return const Center(child: Text('Нет вопросов для текущего раунда'));
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
              'Активный: ${active.theme} | ${active.type.label} | ${active.cost}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(active.text),
            if (active.mediaUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Медиа: ${active.mediaType.label}'),
              if (active.mediaType == QuestionMediaType.image)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Image.network(active.mediaUrl, height: 200),
                )
              else
                Text(active.mediaUrl),
            ],
            const SizedBox(height: 6),
            if (room.phase == GamePhase.questionReveal && isHost)
              ElevatedButton(
                onPressed: () => actions.openBuzzing(roomId),
                child: const Text('Открыть кнопку ответа'),
              ),
            if (room.phase == GamePhase.catTargeting)
              CatTargetingPanel(roomId: roomId, room: room),
            if (room.phase == GamePhase.wagerBidding)
              WagerPanel(roomId: roomId, room: room),
            if (room.phase == GamePhase.answering)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (room.currentAttemptUid != null)
                    Text('Отвечает: ${room.currentAttemptUid}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: room.currentAttemptUid == uid
                            ? () => actions.submitAnswer(roomId)
                            : null,
                        child: const Text('Ответ дал голосом'),
                      ),
                      ElevatedButton(
                        onPressed:
                            GameUiPermissions.canBuzz(room, uid) &&
                                myRole != PlayerRole.spectator
                            ? () => actions.buzz(roomId)
                            : null,
                        child: const Text('Жму кнопку'),
                      ),
                    ],
                  ),
                ],
              ),
            if (room.phase == GamePhase.answerReview && isHost)
              HostJudgePanel(roomId: roomId, room: room),
            if (room.phase == GamePhase.answerReview && !isHost)
              const Text('Ожидается решение ведущего по голосовому ответу'),
            if (room.phase == GamePhase.boardSelect)
              const Text('Выберите следующий вопрос на табло'),
          ],
        ),
      ),
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
      return const Text('Ожидается выбор игрока для Кота в мешке');
    }
    return playersAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, stackTrace) => Text('Ошибка: $error'),
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
                  child: Text('Передать: ${p.nickname}'),
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
            decoration: const InputDecoration(labelText: 'Ставка'),
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
          child: const Text('Подтвердить ставку'),
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
        Text('Кто ответил: ${room.currentAttemptUid ?? '-'}'),
        const Text('Проверка ответа выполняется ведущим голосом'),
        if (room.activeQuestion != null && room.activeQuestion!.aliases.isNotEmpty)
          Text('Допустимые варианты: ${room.activeQuestion!.aliases.join(', ')}'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              onPressed: () =>
                  actions.judgeAnswer(roomId: roomId, correct: true),
              child: const Text('Верно'),
            ),
            ElevatedButton(
              onPressed: () =>
                  actions.judgeAnswer(roomId: roomId, correct: false),
              child: const Text('Неверно'),
            ),
          ],
        ),
      ],
    );
  }
}
