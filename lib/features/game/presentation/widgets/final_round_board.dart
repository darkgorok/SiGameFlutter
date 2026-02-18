import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/loading_screen.dart';
import '../../../../core/l10n.dart';
import '../../application/game_providers.dart';
import '../../game_localizations.dart';
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
          Text(
            '${context.l10n.finalRoundLabel}: ${room.phase.localizedLabel(context)}',
          ),
          Text(context.l10n.eligiblePlayers(room.finalEligibleUids.length)),
          const SizedBox(height: 8),
          if (isHost)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.l10n.finalQuestionSetup),
                    TextField(
                      controller: _themeCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.finalThemeLabel,
                      ),
                    ),
                    TextField(
                      controller: _questionCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.finalQuestionFieldLabel,
                      ),
                    ),
                    TextField(
                      controller: _answerCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.finalControlAnswerLabel,
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
                          child: Text(context.l10n.saveQuestion),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              actions.openFinalWagers(widget.roomId),
                          child: Text(context.l10n.openWagers),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              actions.openFinalAnswers(widget.roomId),
                          child: Text(context.l10n.startVoiceAnswers),
                        ),
                        ElevatedButton(
                          onPressed: () => actions.revealFinal(widget.roomId),
                          child: Text(context.l10n.revealFinal),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (room.finalTheme != null)
            Text('${context.l10n.themeLabel}: ${room.finalTheme}'),
          if (room.phase == GamePhase.finalAnswering &&
              room.finalQuestion != null)
            Text('${context.l10n.questionLabel}: ${room.finalQuestion}'),
          const SizedBox(height: 8),
          if (room.phase == GamePhase.finalWagering &&
              widget.myRole != PlayerRole.spectator)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _wagerCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.yourFinalWager,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => actions.submitFinalWager(
                    roomId: widget.roomId,
                    wager: int.tryParse(_wagerCtrl.text.trim()) ?? 0,
                  ),
                  child: Text(context.l10n.placeWager),
                ),
              ],
            ),
          if (room.phase == GamePhase.finalAnswering)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(context.l10n.discordVoiceInfo),
              ),
            ),
          if (isHost && room.phase == GamePhase.finalAnswering)
            playersAsync.when(
              loading: () => const Center(child: LoadingPane()),
              error: (error, stackTrace) =>
                  Text(context.l10n.errorWithDetails(error.toString())),
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
                                Text(
                                  context.l10n.playerWagerLine(
                                    p.nickname,
                                    p.finalWager,
                                  ),
                                ),
                                Text(
                                  '${context.l10n.decisionLabel}: ${p.finalResult.localizedLabel(context)}',
                                ),
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
                                      child: Text(
                                        context.l10n.finalResultCorrect,
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          actions.setFinalPlayerResult(
                                            roomId: widget.roomId,
                                            targetUid: p.uid,
                                            result: FinalResult.wrong,
                                          ),
                                      child: Text(
                                        context.l10n.finalResultWrong,
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          actions.setFinalPlayerResult(
                                            roomId: widget.roomId,
                                            targetUid: p.uid,
                                            result: FinalResult.noAnswer,
                                          ),
                                      child: Text(
                                        context.l10n.finalResultNoAnswer,
                                      ),
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
