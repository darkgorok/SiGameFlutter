import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/loading_screen.dart';
import '../../../../core/l10n.dart';
import '../../../../core/providers.dart';
import '../../application/game_providers.dart';
import '../../game_localizations.dart';
import '../../game_models.dart';
import '../player_roster_utils.dart';

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
  final _finalAnswerCtrl = TextEditingController();

  @override
  void dispose() {
    _themeCtrl.dispose();
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    _wagerCtrl.dispose();
    _finalAnswerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final uid = ref.watch(currentUserUidProvider) ?? '';
    final isHost = room.hostUid == uid;
    final isSetup = room.phase == GamePhase.finalSetup;
    final isWagering = room.phase == GamePhase.finalWagering;
    final isAnswering = room.phase == GamePhase.finalAnswering;
    final isReveal = room.phase == GamePhase.finalReveal;
    final actions = ref.read(finalActionsProvider);
    final playersAsync = ref.watch(playersStreamProvider(widget.roomId));
    final players = playersAsync.valueOrNull ?? const <PlayerModel>[];
    PlayerModel? me;
    for (final player in players) {
      if (player.uid == uid) {
        me = player;
        break;
      }
    }
    final canOpenWagers =
        isSetup &&
        (room.finalTheme ?? '').isNotEmpty &&
        (room.finalQuestion ?? '').isNotEmpty;
    final wagersSubmitted = allFinalWagersSubmitted(
      eligibleUids: room.finalEligibleUids,
      players: players,
    );
    final canSubmitMyWager =
        isWagering &&
        widget.myRole != PlayerRole.spectator &&
        room.finalEligibleUids.contains(uid) &&
        (me?.finalWagerSubmitted != true);
    final canSubmitMyFinalAnswer =
        isAnswering &&
        widget.myRole != PlayerRole.spectator &&
        room.finalEligibleUids.contains(uid) &&
        (room.finalAnswerCurrentUid ?? '') == uid &&
        (me?.finalAnswerSubmitted != true);
    var allFinalResultsMarked = room.finalEligibleUids.isNotEmpty;
    for (final eligibleUid in room.finalEligibleUids) {
      var finalResult = FinalResult.pending;
      for (final player in players) {
        if (player.uid == eligibleUid) {
          finalResult = player.finalResult;
          break;
        }
      }
      if (finalResult == FinalResult.pending) {
        allFinalResultsMarked = false;
        break;
      }
    }
    final canRevealFinalNow =
        isReveal || (isAnswering && allFinalResultsMarked);
    String resolvePlayerName(String uid) {
      if (uid.isEmpty) {
        return uid;
      }
      for (final player in players) {
        if (player.uid == uid) {
          return player.nickname;
        }
      }
      return uid;
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF102A70), Color(0xFF061539)],
          ),
          border: Border.all(color: const Color(0xFF5F88E8), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1E55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF7BA7FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.finalRoundLabel.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD6E5FF),
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    room.phase.localizedLabel(context),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.eligiblePlayers(room.finalEligibleUids.length),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFBFD2FF)),
                  ),
                  if (room.finalTheme != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${context.l10n.themeLabel}: ${room.finalTheme}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFEAF2FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if ((isAnswering || isReveal) && room.finalQuestion != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        room.finalQuestion!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (room.timerDeadlineAtMs != null) ...[
              _FinalStageTimer(room: room, roomId: widget.roomId),
              const SizedBox(height: 10),
            ],
            if (players.isNotEmpty) ...[
              _FinalPlayersStrip(players: players),
              const SizedBox(height: 10),
            ],
            if (room.finalThemePool.isNotEmpty) ...[
              Text(
                context.l10n.finalThemesList(room.finalThemePool.join(', ')),
                style: const TextStyle(color: Color(0xFFE0EBFF)),
              ),
              if ((room.finalThemeDeleteCurrentUid ?? '').isNotEmpty)
                Text(
                  context.l10n.finalCurrentDeleter(
                    resolvePlayerName(room.finalThemeDeleteCurrentUid!),
                  ),
                  style: const TextStyle(color: Color(0xFFE0EBFF)),
                ),
              if (room.finalThemeDeleteNeedsSelection &&
                  room.finalThemeDeleteCandidates.isNotEmpty)
                Text(
                  context.l10n.finalPickDeleterFrom(
                    room.finalThemeDeleteCandidates
                        .map(resolvePlayerName)
                        .join(', '),
                  ),
                  style: const TextStyle(color: Color(0xFFE0EBFF)),
                ),
            ],
            const SizedBox(height: 8),
            if (isHost && isSetup)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.l10n.finalQuestionSetup),
                      TextField(
                        key: const ValueKey('final_theme_field'),
                        controller: _themeCtrl,
                        decoration: InputDecoration(
                          labelText: context.l10n.finalThemeLabel,
                        ),
                      ),
                      TextField(
                        key: const ValueKey('final_question_field'),
                        controller: _questionCtrl,
                        decoration: InputDecoration(
                          labelText: context.l10n.finalQuestionFieldLabel,
                        ),
                      ),
                      TextField(
                        key: const ValueKey('final_answer_field'),
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
                            key: const ValueKey('final_save_question_button'),
                            onPressed: isSetup
                                ? () => actions.setFinalQuestion(
                                    roomId: widget.roomId,
                                    theme: _themeCtrl.text.trim(),
                                    question: _questionCtrl.text.trim(),
                                    answer: _answerCtrl.text.trim(),
                                  )
                                : null,
                            child: Text(context.l10n.saveQuestion),
                          ),
                          ElevatedButton(
                            key: const ValueKey('final_open_wagers_button'),
                            onPressed: canOpenWagers
                                ? () => actions.openFinalWagers(widget.roomId)
                                : null,
                            child: Text(context.l10n.openWagers),
                          ),
                        ],
                      ),
                      if (isSetup && room.finalThemePool.length > 1) ...[
                        const SizedBox(height: 8),
                        if (room.finalThemeDeleteNeedsSelection &&
                            room.finalThemeDeleteCandidates.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(context.l10n.finalSelectFirstDeleterTie),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: room.finalThemeDeleteCandidates
                                .map(
                                  (candidateUid) => OutlinedButton(
                                    key: ValueKey(
                                      'final_select_deleter_$candidateUid',
                                    ),
                                    onPressed: isHost
                                        ? () => actions.selectFinalThemeDeleter(
                                            roomId: widget.roomId,
                                            targetUid: candidateUid,
                                          )
                                        : null,
                                    child: Text(
                                      context.l10n.finalSelectNamed(
                                        resolvePlayerName(candidateUid),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        Text(
                          context.l10n.finalDeleteTurn(
                            resolvePlayerName(
                              room.finalThemeDeleteCurrentUid ?? '-',
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: room.finalThemePool.map((theme) {
                            final canDelete =
                                isHost ||
                                room.finalThemeDeleteCurrentUid == uid ||
                                (room.finalThemeDeleteCurrentUid ?? '').isEmpty;
                            final canDeleteNow =
                                canDelete &&
                                !room.finalThemeDeleteNeedsSelection;
                            return OutlinedButton(
                              key: ValueKey('final_delete_theme_$theme'),
                              onPressed: canDeleteNow
                                  ? () => actions.deleteFinalTheme(
                                      roomId: widget.roomId,
                                      theme: theme,
                                    )
                                  : null,
                              child: Text(context.l10n.finalDeleteTheme(theme)),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (isHost && isWagering)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        key: const ValueKey('final_open_answers_button'),
                        onPressed:
                            room.finalEligibleUids.isNotEmpty && wagersSubmitted
                            ? () => actions.openFinalAnswers(widget.roomId)
                            : null,
                        child: Text(context.l10n.startVoiceAnswers),
                      ),
                    ],
                  ),
                ),
              ),
            if (isHost && (isAnswering || isReveal))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        key: const ValueKey('final_reveal_button'),
                        onPressed: canRevealFinalNow
                            ? () => actions.revealFinal(widget.roomId)
                            : null,
                        child: Text(context.l10n.revealFinal),
                      ),
                    ],
                  ),
                ),
              ),
            if (room.finalTheme != null)
              Text(
                '${context.l10n.themeLabel}: ${room.finalTheme}',
                style: const TextStyle(color: Color(0xFFE0EBFF)),
              ),
            if ((isAnswering || isReveal) && room.finalQuestion != null)
              Text(
                '${context.l10n.questionLabel}: ${room.finalQuestion}',
                style: const TextStyle(color: Color(0xFFE0EBFF)),
              ),
            if (isAnswering && (room.finalAnswerCurrentUid ?? '').isNotEmpty)
              Text(
                context.l10n.currentAnsweringPlayer(
                  resolvePlayerName(room.finalAnswerCurrentUid!),
                ),
                style: const TextStyle(color: Color(0xFFE0EBFF)),
              ),
            if (isReveal) ...[
              Text(
                context.l10n.finalRevealStep(
                  room.finalRevealIndex + 1,
                  room.finalRevealOrder.length,
                ),
                style: const TextStyle(color: Color(0xFFE0EBFF)),
              ),
              if ((room.finalRevealCurrentUid ?? '').isNotEmpty)
                Text(
                  context.l10n.currentRevealPlayer(
                    resolvePlayerName(room.finalRevealCurrentUid!),
                  ),
                  style: const TextStyle(color: Color(0xFFE0EBFF)),
                ),
            ],
            const SizedBox(height: 8),
            if (isWagering &&
                widget.myRole != PlayerRole.spectator &&
                room.finalEligibleUids.contains(uid))
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('final_wager_field'),
                      controller: _wagerCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.l10n.yourFinalWager,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const ValueKey('final_place_wager_button'),
                    onPressed: canSubmitMyWager
                        ? () => actions.submitFinalWager(
                            roomId: widget.roomId,
                            wager: int.tryParse(_wagerCtrl.text.trim()) ?? 0,
                          )
                        : null,
                    child: Text(context.l10n.placeWager),
                  ),
                ],
              ),
            if (isAnswering &&
                widget.myRole != PlayerRole.spectator &&
                room.finalEligibleUids.contains(uid) &&
                (room.finalAnswerCurrentUid ?? '') == uid)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('final_answer_text_field'),
                      controller: _finalAnswerCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.yourFinalAnswerLabel,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const ValueKey('final_submit_answer_button'),
                    onPressed: canSubmitMyFinalAnswer
                        ? () async {
                            final value = _finalAnswerCtrl.text.trim();
                            if (value.isEmpty) {
                              return;
                            }
                            await actions.submitFinalAnswer(
                              roomId: widget.roomId,
                              answer: value,
                            );
                            _finalAnswerCtrl.clear();
                          }
                        : null,
                    child: Text(context.l10n.submitAnswer),
                  ),
                ],
              ),
            if (isAnswering)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(context.l10n.discordVoiceInfo),
                ),
              ),
            if (isHost && (isAnswering || isReveal))
              playersAsync.when(
                loading: () => const Center(child: LoadingPane()),
                error: (error, stackTrace) =>
                    Text(context.l10n.errorWithDetails(error.toString())),
                data: (players) {
                  final eligible = players
                      .where((p) => room.finalEligibleUids.contains(p.uid))
                      .toList();
                  final orderIndexByUid = <String, int>{};
                  final order = isReveal
                      ? room.finalRevealOrder
                      : room.finalAnswerOrder;
                  for (var i = 0; i < order.length; i += 1) {
                    orderIndexByUid[order[i]] = i;
                  }
                  eligible.sort((a, b) {
                    final ai = orderIndexByUid[a.uid];
                    final bi = orderIndexByUid[b.uid];
                    if (ai != null && bi != null) {
                      return ai.compareTo(bi);
                    }
                    if (ai != null) {
                      return -1;
                    }
                    if (bi != null) {
                      return 1;
                    }
                    return a.nickname.compareTo(b.nickname);
                  });
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
                                  if (isAnswering &&
                                      (room.finalAnswerCurrentUid ?? '') ==
                                          p.uid)
                                    Text(context.l10n.nowAnswering),
                                  if (isAnswering)
                                    Text(
                                      p.finalAnswerSubmitted
                                          ? context.l10n.answerSubmitted
                                          : context.l10n.answerNotSubmitted,
                                    ),
                                  if (p.finalAnswerSubmitted &&
                                      (p.finalAnswerText ?? '').isNotEmpty)
                                    Text(
                                      context.l10n.answerText(
                                        p.finalAnswerText!,
                                      ),
                                    ),
                                  if (isReveal)
                                    Text(
                                      p.finalRevealed
                                          ? context.l10n.revealed
                                          : context.l10n.waitingReveal,
                                    ),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton(
                                        key: ValueKey(
                                          'final_result_correct_${p.uid}',
                                        ),
                                        onPressed:
                                            isAnswering &&
                                                (room.finalAnswerCurrentUid ??
                                                        '') ==
                                                    p.uid
                                            ? () =>
                                                  actions.setFinalPlayerResult(
                                                    roomId: widget.roomId,
                                                    targetUid: p.uid,
                                                    result: FinalResult.correct,
                                                  )
                                            : null,
                                        child: Text(
                                          context.l10n.finalResultCorrect,
                                        ),
                                      ),
                                      OutlinedButton(
                                        key: ValueKey(
                                          'final_result_wrong_${p.uid}',
                                        ),
                                        onPressed:
                                            isAnswering &&
                                                (room.finalAnswerCurrentUid ??
                                                        '') ==
                                                    p.uid
                                            ? () =>
                                                  actions.setFinalPlayerResult(
                                                    roomId: widget.roomId,
                                                    targetUid: p.uid,
                                                    result: FinalResult.wrong,
                                                  )
                                            : null,
                                        child: Text(
                                          context.l10n.finalResultWrong,
                                        ),
                                      ),
                                      OutlinedButton(
                                        key: ValueKey(
                                          'final_result_no_answer_${p.uid}',
                                        ),
                                        onPressed:
                                            isAnswering &&
                                                (room.finalAnswerCurrentUid ??
                                                        '') ==
                                                    p.uid
                                            ? () =>
                                                  actions.setFinalPlayerResult(
                                                    roomId: widget.roomId,
                                                    targetUid: p.uid,
                                                    result:
                                                        FinalResult.noAnswer,
                                                  )
                                            : null,
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
      ),
    );
  }
}

class _FinalStageTimer extends ConsumerStatefulWidget {
  const _FinalStageTimer({required this.room, required this.roomId});

  final RoomModel room;
  final String roomId;

  @override
  ConsumerState<_FinalStageTimer> createState() => _FinalStageTimerState();
}

class _FinalStageTimerState extends ConsumerState<_FinalStageTimer> {
  Timer? _timer;
  int _leftSec = 0;
  bool _expiredHandled = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant _FinalStageTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.timerDeadlineAtMs != widget.room.timerDeadlineAtMs) {
      _expiredHandled = false;
      _tick();
    }
  }

  void _tick() {
    final deadline = widget.room.timerDeadlineAtMs;
    if (deadline == null) {
      if (_leftSec != 0 && mounted) {
        setState(() => _leftSec = 0);
      }
      return;
    }
    final leftMs = deadline - DateTime.now().millisecondsSinceEpoch;
    final nextLeftSec = leftMs <= 0 ? 0 : (leftMs / 1000).ceil();
    if (mounted && nextLeftSec != _leftSec) {
      setState(() => _leftSec = nextLeftSec);
    }

    final isHost = widget.room.hostUid == (ref.read(currentUserUidProvider));
    if (nextLeftSec == 0 && !_expiredHandled && isHost) {
      _expiredHandled = true;
      ref.read(questionActionsProvider).handleTimerExpiration(widget.roomId);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final danger = _leftSec <= 5;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFF9E1B32) : const Color(0xFF0A1A45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: danger ? const Color(0xFFFF8A9A) : const Color(0xFF8AB1FF),
          width: 1.5,
        ),
      ),
      child: Text(
        context.l10n.timerSeconds(_leftSec),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FinalPlayersStrip extends StatelessWidget {
  const _FinalPlayersStrip({required this.players});

  final List<PlayerModel> players;

  @override
  Widget build(BuildContext context) {
    final visiblePlayers =
        players.where((p) => p.role != PlayerRole.spectator).toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC081434),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5A7FD4)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: visiblePlayers
            .map(
              (player) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF102964),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF84A9FF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player.nickname,
                      style: const TextStyle(
                        color: Color(0xFFEAF1FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${player.score}',
                      style: const TextStyle(
                        color: Color(0xFFFFD766),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
