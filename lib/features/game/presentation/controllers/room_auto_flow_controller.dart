import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../application/game_providers.dart';
import '../../game_models.dart';

class RoomAutoFlowController {
  RoomAutoFlowController({required this.enabled});

  final bool enabled;
  bool _busy = false;
  String _lastActionKey = '';
  String _lastPhaseSignature = '';
  int _lastActionQueuedAtMs = 0;
  Timer? _timer;
  String? _lastActiveQuestionId;
  final Set<String> _submittedNumericQuestionIds = <String>{};
  static const Duration _sameActionRetryDelay = Duration(seconds: 4);

  bool _isDeadlineExpired(RoomModel room) {
    final deadline = room.timerDeadlineAtMs;
    if (deadline == null) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch >= deadline;
  }

  void dispose() {
    _timer?.cancel();
  }

  void _queueAction({
    required String key,
    required Duration delay,
    required Future<void> Function() action,
    required bool mounted,
  }) {
    if (!enabled || _busy || !mounted) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastActionKey == key &&
        nowMs - _lastActionQueuedAtMs < _sameActionRetryDelay.inMilliseconds) {
      return;
    }
    _lastActionKey = key;
    _lastActionQueuedAtMs = nowMs;
    _busy = true;
    _timer?.cancel();
    _timer = Timer(delay, () async {
      try {
        if (!enabled || !mounted) {
          return;
        }
        await action();
      } catch (_) {
        // Best-effort automation: realtime updates may race this branch.
      } finally {
        _busy = false;
      }
    });
  }

  void drive({
    required bool mounted,
    required RoomModel room,
    required List<PlayerModel> players,
    required List<QuestionModel> questions,
    required PlayerRole myRole,
    required bool isHost,
    required String roomId,
    required RoomActions roomActions,
    required QuestionActions questionActions,
    required FinalActions finalActions,
  }) {
    if (!isHost || !enabled || room.status == GameStatus.paused) {
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final me = _maybeByUid(players, uid);
    final myConnected = me?.connected == true;
    final signature = <String>[
      room.status.value,
      room.phase.value,
      room.currentRound.toString(),
      room.activeQuestion?.id ?? '',
      room.timerDeadlineAtMs?.toString() ?? '',
      room.currentAttemptUid ?? '',
      room.finalAnswerCurrentUid ?? '',
      room.finalRevealCurrentUid ?? '',
      room.finalRevealIndex.toString(),
      room.finalAnswerIndex.toString(),
    ].join('|');
    if (_lastPhaseSignature != signature) {
      _lastPhaseSignature = signature;
      _lastActionKey = '';
    }

    final activeId = room.activeQuestion?.id;
    if (activeId != _lastActiveQuestionId) {
      _lastActiveQuestionId = activeId;
      if (activeId == null) {
        _submittedNumericQuestionIds.clear();
      }
    }

    if (room.phase == GamePhase.lobby &&
        room.status == GameStatus.lobby &&
        questions.isNotEmpty) {
      _queueAction(
        key: 'lobby_start_${questions.length}',
        delay: const Duration(seconds: 2),
        action: () => roomActions.startGame(roomId),
        mounted: mounted,
      );
      return;
    }

    if (room.phase == GamePhase.boardSelect && room.activeQuestion == null) {
      final roundQuestions =
          questions
              .where((q) => q.round == room.currentRound && !q.used)
              .toList()
            ..sort((a, b) {
              final byTheme = a.theme.compareTo(b.theme);
              if (byTheme != 0) return byTheme;
              return a.cost.compareTo(b.cost);
            });

      if (roundQuestions.isNotEmpty) {
        final q = roundQuestions.first;
        _queueAction(
          key: 'pick_${room.currentRound}_${q.id}',
          delay: const Duration(seconds: 2),
          action: () =>
              questionActions.pickQuestion(roomId: roomId, questionId: q.id),
          mounted: mounted,
        );
      } else {
        final hasHigherRoundQuestions = questions.any(
          (q) => q.round > room.currentRound && !q.used,
        );
        _queueAction(
          key: 'advance_${room.currentRound}',
          delay: const Duration(seconds: 2),
          action: () => hasHigherRoundQuestions
              ? roomActions.advanceToRound2(roomId)
              : roomActions.startFinalRound(roomId),
          mounted: mounted,
        );
      }
      return;
    }

    if (room.phase == GamePhase.questionReveal && room.activeQuestion != null) {
      if (_isDeadlineExpired(room)) {
        _queueAction(
          key: 'question_reveal_timeout_${room.timerDeadlineAtMs}',
          delay: const Duration(seconds: 1),
          action: () => questionActions.handleTimerExpiration(roomId),
          mounted: mounted,
        );
      } else {
        _queueAction(
          key: 'open_buzz_${room.activeQuestion!.id}',
          delay: const Duration(seconds: 2),
          action: () => questionActions.openBuzzing(roomId),
          mounted: mounted,
        );
      }
      return;
    }

    if (room.phase == GamePhase.catTargeting) {
      final candidates = players.where(_isActiveVoicePlayer).toList();
      if (candidates.isNotEmpty) {
        final chooserUid = room.chooserUid ?? '';
        PlayerModel target = candidates.first;
        for (final candidate in candidates) {
          if (candidate.uid != chooserUid) {
            target = candidate;
            break;
          }
        }
        _queueAction(
          key: 'cat_${room.activeQuestion?.id}_${target.uid}',
          delay: const Duration(seconds: 2),
          action: () => questionActions.selectCatTarget(roomId, target.uid),
          mounted: mounted,
        );
      } else if (_isDeadlineExpired(room)) {
        _queueAction(
          key: 'cat_timeout_${room.timerDeadlineAtMs}',
          delay: const Duration(seconds: 1),
          action: () => questionActions.handleTimerExpiration(roomId),
          mounted: mounted,
        );
      }
      return;
    }

    if (room.phase == GamePhase.wagerBidding) {
      if (_isDeadlineExpired(room)) {
        _queueAction(
          key: 'wager_timeout_${room.timerDeadlineAtMs}',
          delay: const Duration(seconds: 1),
          action: () => questionActions.handleTimerExpiration(roomId),
          mounted: mounted,
        );
      } else {
        final wager = room.activeQuestion?.cost ?? 100;
        _queueAction(
          key: 'wager_${room.activeQuestion?.id}_$wager',
          delay: const Duration(seconds: 2),
          action: () =>
              questionActions.setWagerAndOpen(roomId: roomId, wager: wager),
          mounted: mounted,
        );
      }
      return;
    }

    if (room.phase == GamePhase.answering && room.activeQuestion != null) {
      if (room.activeQuestion!.type == QuestionType.closestNumber) {
        final qid = room.activeQuestion!.id;
        if (myConnected &&
            myRole != PlayerRole.spectator &&
            !_submittedNumericQuestionIds.contains(qid)) {
          _submittedNumericQuestionIds.add(qid);
          _queueAction(
            key: 'numeric_$qid',
            delay: const Duration(seconds: 2),
            action: () => questionActions.submitNumericAnswer(
              roomId: roomId,
              value: room.activeQuestion!.cost,
            ),
            mounted: mounted,
          );
        }
        if (_isDeadlineExpired(room)) {
          _queueAction(
            key: 'closest_timeout_${room.timerDeadlineAtMs}',
            delay: const Duration(seconds: 1),
            action: () => questionActions.handleTimerExpiration(roomId),
            mounted: mounted,
          );
        }
        return;
      }

      if (room.currentAttemptUid == null &&
          myConnected &&
          myRole != PlayerRole.spectator) {
        if (_isDeadlineExpired(room)) {
          _queueAction(
            key: 'answering_idle_timeout_${room.timerDeadlineAtMs}',
            delay: const Duration(seconds: 1),
            action: () => questionActions.handleTimerExpiration(roomId),
            mounted: mounted,
          );
        } else {
          _queueAction(
            key: 'buzz_${room.activeQuestion!.id}',
            delay: const Duration(seconds: 2),
            action: () => questionActions.buzz(roomId),
            mounted: mounted,
          );
        }
        return;
      }

      if (room.currentAttemptUid == uid) {
        _queueAction(
          key: 'submit_${room.activeQuestion!.id}_$uid',
          delay: const Duration(seconds: 2),
          action: () => questionActions.submitAnswer(roomId),
          mounted: mounted,
        );
        return;
      }

      if (_isDeadlineExpired(room)) {
        _queueAction(
          key: 'answering_timeout_${room.timerDeadlineAtMs}',
          delay: const Duration(seconds: 1),
          action: () => questionActions.handleTimerExpiration(roomId),
          mounted: mounted,
        );
      }
    }

    if (room.phase == GamePhase.answerReview && room.activeQuestion != null) {
      if (_isDeadlineExpired(room)) {
        _queueAction(
          key: 'answer_review_timeout_${room.timerDeadlineAtMs}',
          delay: const Duration(seconds: 1),
          action: () => questionActions.handleTimerExpiration(roomId),
          mounted: mounted,
        );
      } else {
        _queueAction(
          key: 'judge_${room.activeQuestion!.id}',
          delay: const Duration(seconds: 2),
          action: () =>
              questionActions.judgeAnswer(roomId: roomId, correct: true),
          mounted: mounted,
        );
      }
      return;
    }

    if (room.phase == GamePhase.finalSetup) {
      if (room.finalThemePool.length > 1) {
        if (room.finalThemeDeleteNeedsSelection &&
            (room.finalThemeDeleteCurrentUid ?? '').isEmpty &&
            room.finalThemeDeleteCandidates.isNotEmpty) {
          final firstCandidate = room.finalThemeDeleteCandidates.first;
          _queueAction(
            key: 'final_select_deleter_$firstCandidate',
            delay: const Duration(seconds: 2),
            action: () => finalActions.selectFinalThemeDeleter(
              roomId: roomId,
              targetUid: firstCandidate,
            ),
            mounted: mounted,
          );
        } else {
          final themeToDelete = room.finalThemePool.first;
          _queueAction(
            key: 'final_delete_$themeToDelete',
            delay: const Duration(seconds: 2),
            action: () => finalActions.deleteFinalTheme(
              roomId: roomId,
              theme: themeToDelete,
            ),
            mounted: mounted,
          );
        }
      } else if ((room.finalTheme ?? '').isEmpty ||
          (room.finalQuestion ?? '').isEmpty) {
        _queueAction(
          key: 'final_set_question',
          delay: const Duration(seconds: 2),
          action: () => finalActions.setFinalQuestion(
            roomId: roomId,
            theme: 'Final',
            question: 'Final question',
            answer: 'Final answer',
          ),
          mounted: mounted,
        );
      } else {
        _queueAction(
          key: 'final_open_wagers',
          delay: const Duration(seconds: 2),
          action: () => finalActions.openFinalWagers(roomId),
          mounted: mounted,
        );
      }
      return;
    }

    if (room.phase == GamePhase.finalWagering) {
      final eligible = room.finalEligibleUids.contains(uid);
      if (eligible &&
          me != null &&
          me.connected &&
          me.role != PlayerRole.spectator &&
          !me.finalWagerSubmitted) {
        final wager = me.score > 0 ? (me.score > 300 ? 300 : me.score) : 0;
        _queueAction(
          key: 'final_wager_$uid',
          delay: const Duration(seconds: 2),
          action: () =>
              finalActions.submitFinalWager(roomId: roomId, wager: wager),
          mounted: mounted,
        );
      } else {
        final allSubmitted = room.finalEligibleUids.every((eligibleUid) {
          final player = _findByUid(players, eligibleUid);
          return player.uid.isNotEmpty && player.finalWagerSubmitted;
        });
        if (allSubmitted) {
          _queueAction(
            key: 'final_open_answers',
            delay: const Duration(seconds: 2),
            action: () => finalActions.openFinalAnswers(roomId),
            mounted: mounted,
          );
        } else if (_isDeadlineExpired(room)) {
          _queueAction(
            key: 'final_wager_timeout_${room.timerDeadlineAtMs}',
            delay: const Duration(seconds: 1),
            action: () => questionActions.handleTimerExpiration(roomId),
            mounted: mounted,
          );
        }
      }
      return;
    }

    if (room.phase == GamePhase.finalAnswering) {
      final currentFinalUid = (room.finalAnswerCurrentUid ?? '').trim();
      final pending = currentFinalUid.isNotEmpty
          ? _findByUid(players, currentFinalUid)
          : _findFirstPendingFinal(players, room.finalEligibleUids);
      if (pending.uid.isNotEmpty) {
        if (!pending.finalAnswerSubmitted) {
          if (pending.uid == uid &&
              myConnected &&
              myRole != PlayerRole.spectator) {
            _queueAction(
              key: 'final_submit_answer_$uid',
              delay: const Duration(seconds: 2),
              action: () => finalActions.submitFinalAnswer(
                roomId: roomId,
                answer: 'Auto final answer',
              ),
              mounted: mounted,
            );
            return;
          }
          if (_isDeadlineExpired(room)) {
            _queueAction(
              key: 'final_answer_timeout_${room.timerDeadlineAtMs}',
              delay: const Duration(seconds: 1),
              action: () => questionActions.handleTimerExpiration(roomId),
              mounted: mounted,
            );
          }
        } else {
          final result = pending.uid == uid
              ? FinalResult.correct
              : FinalResult.wrong;
          _queueAction(
            key: 'final_mark_${pending.uid}',
            delay: const Duration(seconds: 2),
            action: () => finalActions.setFinalPlayerResult(
              roomId: roomId,
              targetUid: pending.uid,
              result: result,
            ),
            mounted: mounted,
          );
        }
      } else {
        _queueAction(
          key: 'final_reveal',
          delay: const Duration(seconds: 2),
          action: () => finalActions.revealFinal(roomId),
          mounted: mounted,
        );
      }
      return;
    }

    if (room.phase == GamePhase.finalReveal) {
      if (_isDeadlineExpired(room)) {
        _queueAction(
          key: 'final_reveal_timeout_${room.timerDeadlineAtMs}',
          delay: const Duration(seconds: 1),
          action: () => questionActions.handleTimerExpiration(roomId),
          mounted: mounted,
        );
      } else {
        _queueAction(
          key:
              'final_reveal_step_${room.finalRevealIndex}_${room.finalRevealCurrentUid ?? ''}',
          delay: const Duration(seconds: 2),
          action: () => finalActions.revealFinal(roomId),
          mounted: mounted,
        );
      }
    }
  }

  PlayerModel _findByUid(List<PlayerModel> players, String uid) {
    for (final player in players) {
      if (player.uid == uid) {
        return player;
      }
    }
    return _emptyPlayer();
  }

  PlayerModel? _maybeByUid(List<PlayerModel> players, String uid) {
    for (final player in players) {
      if (player.uid == uid) {
        return player;
      }
    }
    return null;
  }

  bool _isActiveVoicePlayer(PlayerModel player) {
    return player.connected && player.role != PlayerRole.spectator;
  }

  PlayerModel _findFirstPendingFinal(
    List<PlayerModel> players,
    List<String> eligibleUids,
  ) {
    for (final player in players) {
      if (eligibleUids.contains(player.uid) &&
          player.finalResult == FinalResult.pending) {
        return player;
      }
    }
    return _emptyPlayer();
  }

  PlayerModel _emptyPlayer() {
    return PlayerModel(
      uid: '',
      nickname: '',
      avatarUrl: '',
      role: PlayerRole.player,
      score: 0,
      connected: false,
      correctAnswers: 0,
      wrongAnswers: 0,
      buzzCount: 0,
      finalWager: 0,
      finalWagerSubmitted: false,
      finalAnswerSubmitted: false,
      finalAnswerText: null,
      finalResult: FinalResult.pending,
      finalRevealed: false,
    );
  }
}
