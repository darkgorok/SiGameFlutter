import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/loading_screen.dart';
import '../../../../core/l10n.dart';
import '../../../../core/providers.dart';
import '../../application/game_providers.dart';
import '../../game_localizations.dart';
import '../../game_models.dart';
import '../controllers/game_ui_permissions.dart';

class QuestionBoard extends ConsumerStatefulWidget {
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
  ConsumerState<QuestionBoard> createState() => _QuestionBoardState();
}

class _QuestionBoardState extends ConsumerState<QuestionBoard> {
  Timer? _questionFlashTimer;
  Timer? _timeoutFlashTimer;
  bool _questionFlashVisible = false;
  bool _timeoutFlashVisible = false;

  @override
  void didUpdateWidget(covariant QuestionBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.room.activeQuestion?.id;
    final nextId = widget.room.activeQuestion?.id;
    if (oldId != nextId && nextId != null) {
      _triggerQuestionFx();
    }
  }

  void _triggerQuestionFx() {
    SystemSound.play(SystemSoundType.click);
    _questionFlashTimer?.cancel();
    if (mounted) {
      setState(() => _questionFlashVisible = true);
    }
    _questionFlashTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
        setState(() => _questionFlashVisible = false);
      }
    });
  }

  void _triggerTimeoutFx() {
    SystemSound.play(SystemSoundType.alert);
    _timeoutFlashTimer?.cancel();
    if (mounted) {
      setState(() => _timeoutFlashVisible = true);
    }
    _timeoutFlashTimer = Timer(const Duration(milliseconds: 320), () {
      if (mounted) {
        setState(() => _timeoutFlashVisible = false);
      }
    });
  }

  @override
  void dispose() {
    _questionFlashTimer?.cancel();
    _timeoutFlashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserUidProvider) ?? '';
    final players = ref.watch(playersStreamProvider(widget.roomId)).valueOrNull;
    final groupedAsync = ref.watch(
      groupedQuestionsProvider(
        RoomQuestionsArgs(
          roomId: widget.roomId,
          round: widget.room.currentRound,
        ),
      ),
    );
    final actions = ref.read(questionActionsProvider);
    return groupedAsync.when(
      loading: () => const Center(child: LoadingPane()),
      error: (error, stackTrace) =>
          Center(child: Text(context.l10n.errorWithDetails(error.toString()))),
      data: (board) {
        if (board.themes.isEmpty) {
          return Center(child: Text(context.l10n.noQuestionsCurrentRound));
        }

        return Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0F2D77), Color(0xFF041236)],
                  ),
                  border: Border.all(color: const Color(0xFF4A79E2), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _ClassicBoardTable(
                          room: widget.room,
                          roomId: widget.roomId,
                          board: board,
                          currentUid: uid,
                          onPick: (questionId) => actions.pickQuestion(
                            roomId: widget.roomId,
                            questionId: questionId,
                          ),
                        ),
                      ),
                      if (widget.room.timerDeadlineAtMs != null)
                        Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _BoardStageTimer(
                              room: widget.room,
                              roomId: widget.roomId,
                              onExpiredVisual: _triggerTimeoutFx,
                            ),
                          ),
                        ),
                      if ((players ?? const <PlayerModel>[]).isNotEmpty)
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 12,
                          child: _BoardPlayersStrip(players: players!),
                        ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 220),
                            opacity: _questionFlashVisible ? 1 : 0,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(0, -0.1),
                                  radius: 0.7,
                                  colors: [
                                    Color(0x80FFFFFF),
                                    Color(0x00FFFFFF),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _timeoutFlashVisible ? 1 : 0,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 1.2,
                                  colors: [
                                    Color(0x66FF3B4E),
                                    Color(0x00FF3B4E),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final fade = CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            );
                            final scale = Tween<double>(begin: 0.94, end: 1.0)
                                .animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutBack,
                                  ),
                                );
                            return FadeTransition(
                              opacity: fade,
                              child: ScaleTransition(
                                scale: scale,
                                child: child,
                              ),
                            );
                          },
                          child: widget.room.activeQuestion == null
                              ? const SizedBox.shrink()
                              : ColoredBox(
                                  key: ValueKey(
                                    'active_overlay_${widget.room.activeQuestion!.id}',
                                  ),
                                  color: const Color(0xCC010615),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: constraints.maxWidth > 900
                                            ? 900
                                            : constraints.maxWidth - 24,
                                      ),
                                      child: ActiveQuestionPanel(
                                        room: widget.room,
                                        roomId: widget.roomId,
                                        myRole: widget.myRole,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BoardPlayersStrip extends StatelessWidget {
  const _BoardPlayersStrip({required this.players});

  final List<PlayerModel> players;

  @override
  Widget build(BuildContext context) {
    final activePlayers =
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
        children: activePlayers
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

class _ClassicBoardTable extends StatelessWidget {
  const _ClassicBoardTable({
    required this.room,
    required this.roomId,
    required this.board,
    required this.currentUid,
    required this.onPick,
  });

  final RoomModel room;
  final String roomId;
  final GroupedQuestionBoard board;
  final String currentUid;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final themes = board.themes;
    final costs =
        board.grouped.values
            .expand((list) => list.map((q) => q.cost))
            .toSet()
            .toList()
          ..sort();
    final byThemeAndCost = <String, Map<int, QuestionModel>>{};
    for (final theme in themes) {
      final inner = <int, QuestionModel>{};
      for (final q in board.grouped[theme] ?? const <QuestionModel>[]) {
        inner[q.cost] = q;
      }
      byThemeAndCost[theme] = inner;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 780),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder.symmetric(
              inside: const BorderSide(color: Color(0xAA7BA5FF), width: 1),
              outside: const BorderSide(color: Color(0xFF7BA5FF), width: 2),
            ),
            columnWidths: {
              for (var i = 0; i < themes.length; i++)
                i: const FlexColumnWidth(),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFF184AB9)),
                children: themes
                    .map(
                      (theme) => SizedBox(
                        height: 84,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              theme.toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFEAF2FF),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              ...costs.map((cost) {
                return TableRow(
                  decoration: const BoxDecoration(color: Color(0xFF0D2E85)),
                  children: themes.map((theme) {
                    final q = byThemeAndCost[theme]?[cost];
                    if (q == null) {
                      return const SizedBox(height: 104);
                    }
                    final canPick =
                        GameUiPermissions.canPickQuestion(room, currentUid) &&
                        !q.used;
                    return InkWell(
                      key: ValueKey(
                        'room_pick_question_${q.id}_${q.cost}_${q.type.value}_${q.mediaType.value}',
                      ),
                      onTap: canPick ? () => onPick(q.id) : null,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final rotate = Tween<double>(
                            begin: 1.57,
                            end: 0,
                          ).animate(animation);
                          return AnimatedBuilder(
                            animation: rotate,
                            child: child,
                            builder: (context, value) {
                              final matrix = Matrix4.identity()
                                ..setEntry(3, 2, 0.002)
                                ..rotateY(rotate.value);
                              return Transform(
                                transform: matrix,
                                alignment: Alignment.center,
                                child: value,
                              );
                            },
                          );
                        },
                        child: Container(
                          key: ValueKey('${q.id}_${q.used ? 'used' : 'open'}'),
                          height: 104,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: q.used
                                ? const Color(0xFF20305A)
                                : const Color(0xFF153C98),
                          ),
                          child: Text(
                            q.used ? '' : '${q.cost}',
                            style: TextStyle(
                              color: q.used
                                  ? const Color(0xFF7487B7)
                                  : const Color(0xFFFFD54F),
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              shadows: const [
                                Shadow(
                                  color: Color(0xCC000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardStageTimer extends ConsumerStatefulWidget {
  const _BoardStageTimer({
    required this.room,
    required this.roomId,
    this.onExpiredVisual,
  });

  final RoomModel room;
  final String roomId;
  final VoidCallback? onExpiredVisual;

  @override
  ConsumerState<_BoardStageTimer> createState() => _BoardStageTimerState();
}

class _BoardStageTimerState extends ConsumerState<_BoardStageTimer> {
  Timer? _timer;
  bool _expiredHandled = false;
  bool _expiredVisualNotified = false;
  int _leftSec = 0;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant _BoardStageTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.timerDeadlineAtMs != widget.room.timerDeadlineAtMs) {
      _expiredHandled = false;
      _expiredVisualNotified = false;
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
    final safeSec = leftMs <= 0 ? 0 : (leftMs / 1000).ceil();
    if (mounted && safeSec != _leftSec) {
      setState(() => _leftSec = safeSec);
    }
    if (safeSec == 0 && !_expiredVisualNotified) {
      _expiredVisualNotified = true;
      widget.onExpiredVisual?.call();
    }
    final isHost = widget.room.hostUid == (ref.read(currentUserUidProvider));
    if (safeSec == 0 && !_expiredHandled && isHost) {
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
      duration: const Duration(milliseconds: 240),
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
          letterSpacing: 0.5,
        ),
      ),
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
    final players = ref.watch(playersStreamProvider(roomId)).valueOrNull;
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

    final uid = ref.watch(currentUserUidProvider) ?? '';
    final isHost = uid == room.hostUid;
    final actions = ref.read(questionActionsProvider);

    return Material(
      color: const Color(0xFF071B4D),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                active.theme.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFBCD3FF),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                active.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (active.mediaUrl.isNotEmpty) ...[
                _QuestionMediaPreview(
                  url: active.mediaUrl,
                  mediaType: active.mediaType,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                context.l10n.activeQuestionHeader(
                  active.theme,
                  active.type.localizedLabel(context),
                  active.cost,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF9CB8F9)),
              ),
              const SizedBox(height: 10),
              if (room.phase == GamePhase.questionReveal && isHost)
                ElevatedButton(
                  key: const ValueKey('room_open_buzzing_button'),
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
                              '${context.l10n.answeringNow}: ${resolvePlayerName(room.currentAttemptUid!)}',
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(
                                key: const ValueKey(
                                  'room_submit_voice_answer_button',
                                ),
                                onPressed: room.currentAttemptUid == uid
                                    ? () => actions.submitAnswer(roomId)
                                    : null,
                                child: Text(context.l10n.answeredByVoice),
                              ),
                              ElevatedButton(
                                key: const ValueKey('room_buzz_button'),
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
                Text(
                  context.l10n.waitingHostDecision,
                  textAlign: TextAlign.center,
                ),
              if (room.phase == GamePhase.boardSelect)
                Text(
                  context.l10n.chooseNextQuestion,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionMediaPreview extends StatelessWidget {
  const _QuestionMediaPreview({required this.url, required this.mediaType});

  final String url;
  final QuestionMediaType mediaType;

  @override
  Widget build(BuildContext context) {
    if (mediaType == QuestionMediaType.audio ||
        mediaType == QuestionMediaType.video) {
      return Container(
        constraints: const BoxConstraints(minHeight: 260),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1C4F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF5A83DE)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              mediaType == QuestionMediaType.audio
                  ? Icons.graphic_eq
                  : Icons.ondemand_video,
              color: const Color(0xFFD7E6FF),
              size: 52,
            ),
            const SizedBox(height: 8),
            Text(
              mediaType == QuestionMediaType.audio
                  ? context.l10n.mediaPreviewAudio
                  : context.l10n.mediaPreviewVideo,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              url,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE1EBFF)),
            ),
          ],
        ),
      );
    }

    if (url.startsWith('data:image/')) {
      final comma = url.indexOf(',');
      if (comma > 0) {
        try {
          final encoded = url.substring(comma + 1);
          final bytes = base64Decode(encoded);
          return Image.memory(
            bytes,
            height: 280,
            fit: BoxFit.contain,
            errorBuilder: _errorBuilder,
          );
        } catch (_) {
          return _errorBuilder(context, 'invalid_data_url', null);
        }
      }
    }
    return Image.network(
      url,
      height: 280,
      fit: BoxFit.contain,
      errorBuilder: _errorBuilder,
    );
  }

  Widget _errorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return SizedBox(
      height: 280,
      child: Center(child: Text(context.l10n.mediaPreviewUnavailable)),
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
    final actions = ref.read(questionActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.closestNumberHint),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('room_numeric_answer_field'),
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
              key: const ValueKey('room_submit_numeric_answer_button'),
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
    final actions = ref.read(questionActionsProvider);
    final uid = ref.watch(currentUserUidProvider) ?? '';
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
                  key: ValueKey('room_cat_target_${p.uid}'),
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
    final uid = ref.watch(currentUserUidProvider) ?? '';
    final room = widget.room;
    final actions = ref.read(questionActionsProvider);
    final canSetWager = uid == room.chooserUid || uid == room.hostUid;

    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('room_wager_field'),
            controller: _wagerCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.l10n.wagerLabel),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          key: const ValueKey('room_confirm_wager_button'),
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
    final actions = ref.read(questionActionsProvider);
    final players = ref.watch(playersStreamProvider(roomId)).valueOrNull;
    String resolvePlayerName(String uid) {
      if (uid.isEmpty) {
        return uid;
      }
      if (players != null) {
        for (final player in players) {
          if (player.uid == uid) {
            return player.nickname;
          }
        }
      }
      return uid;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.whoAnswered(
            resolvePlayerName(room.currentAttemptUid ?? '-'),
          ),
        ),
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
              key: const ValueKey('room_judge_correct_button'),
              onPressed: () =>
                  actions.judgeAnswer(roomId: roomId, correct: true),
              child: Text(context.l10n.finalResultCorrect),
            ),
            ElevatedButton(
              key: const ValueKey('room_judge_wrong_button'),
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
