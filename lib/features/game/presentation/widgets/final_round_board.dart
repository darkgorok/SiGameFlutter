import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_providers.dart';
import '../../game_models.dart';

class FinalRoundBoard extends ConsumerStatefulWidget {
  const FinalRoundBoard({
    super.key,
    required this.room,
    required this.roomId,
    required this.myRole,
  });

  final RoomModel room;
  final String roomId;
  final PlayerRole myRole;

  @override
  ConsumerState<FinalRoundBoard> createState() => _FinalRoundBoardState();
}

class _FinalRoundBoardState extends ConsumerState<FinalRoundBoard> {
  final _themeCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _wagerCtrl = TextEditingController(text: '100');

  @override
  void dispose() {
    _themeCtrl.dispose();
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    _wagerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final isHost = room.hostUid == uid;
    final actions = ref.read(gameActionsControllerProvider.notifier);
    final playersAsync = ref.watch(playersStreamProvider(widget.roomId));

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Text('Финальный раунд: ${room.phase.label}'),
          Text('Допущены: ${room.finalEligibleUids.length} игроков'),
          const SizedBox(height: 8),
          if (isHost)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Настройка финального вопроса'),
                    TextField(
                      controller: _themeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Тема финала',
                      ),
                    ),
                    TextField(
                      controller: _questionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Вопрос финала',
                      ),
                    ),
                    TextField(
                      controller: _answerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Контрольный ответ (для ведущего)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () => actions.setFinalQuestion(
                            roomId: widget.roomId,
                            theme: _themeCtrl.text.trim(),
                            question: _questionCtrl.text.trim(),
                            answer: _answerCtrl.text.trim(),
                          ),
                          child: const Text('Сохранить вопрос'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              actions.openFinalWagers(widget.roomId),
                          child: const Text('Открыть ставки'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              actions.openFinalAnswers(widget.roomId),
                          child: const Text('Начать голосовые ответы'),
                        ),
                        ElevatedButton(
                          onPressed: () => actions.revealFinal(widget.roomId),
                          child: const Text('Вскрыть финал'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (room.finalTheme != null) Text('Тема: ${room.finalTheme}'),
          if (room.phase == GamePhase.finalAnswering &&
              room.finalQuestion != null)
            Text('Вопрос: ${room.finalQuestion}'),
          const SizedBox(height: 8),
          if (room.phase == GamePhase.finalWagering &&
              widget.myRole != PlayerRole.spectator)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _wagerCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ваша финальная ставка',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => actions.submitFinalWager(
                    roomId: widget.roomId,
                    wager: int.tryParse(_wagerCtrl.text.trim()) ?? 0,
                  ),
                  child: const Text('Поставить'),
                ),
              ],
            ),
          if (room.phase == GamePhase.finalAnswering)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Ответы даются только голосом в Discord. Ведущий отмечает исход каждого ответа.',
                ),
              ),
            ),
          if (isHost && room.phase == GamePhase.finalAnswering)
            playersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('Ошибка: $error'),
              data: (players) {
                final eligible = players
                    .where((p) => room.finalEligibleUids.contains(p.uid))
                    .toList();
                return Column(
                  children: eligible
                      .map(
                        (p) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${p.nickname} | ставка: ${p.finalWager}'),
                                Text('Решение: ${p.finalResult.label}'),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () =>
                                          actions.setFinalPlayerResult(
                                            roomId: widget.roomId,
                                            targetUid: p.uid,
                                            result: FinalResult.correct,
                                          ),
                                      child: const Text('Верно'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          actions.setFinalPlayerResult(
                                            roomId: widget.roomId,
                                            targetUid: p.uid,
                                            result: FinalResult.wrong,
                                          ),
                                      child: const Text('Неверно'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          actions.setFinalPlayerResult(
                                            roomId: widget.roomId,
                                            targetUid: p.uid,
                                            result: FinalResult.noAnswer,
                                          ),
                                      child: const Text('Без ответа'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}
